# users/signals.py
from django.db.models.signals import post_save, post_delete, m2m_changed
from django.dispatch import receiver

from recipes.models import Recipe, Homework
from ingredients.models import IngredientPost

from .models import UserPost, PointTransaction
from .point_rules import PointRules


# ============================================================
# Helpers
# ============================================================

def _like_key(liker, target):
    return f"{liker.user_id}:{target.id}"


def _author_of(target):
    if isinstance(target, (Recipe, IngredientPost)):
        return target.author
    if isinstance(target, Homework):
        return target.user
    return None


def _counter_field_for(target):
    if isinstance(target, Recipe):
        return 'recipe_likes_received'
    if isinstance(target, IngredientPost):
        return 'ingredient_likes_received'
    if isinstance(target, Homework):
        return 'dish_likes_received'
    return None


def _points_for_like(liker, target):
    if isinstance(target, (Recipe, IngredientPost)):
        if liker.is_official or liker.is_expert:
            return PointRules.RECEIVE_LIKE_PRIORITY, 'receive_like'
        return PointRules.RECEIVE_LIKE, 'receive_like'

    if isinstance(target, Homework):
        if getattr(target, 'recipe', None) is not None and liker.id == target.recipe.author_id:
            return PointRules.CHEF_LIKE_DISH, 'chef_like_dish'
        return PointRules.RECEIVE_LIKE, 'receive_like'

    return 0, None


def _bump_like_counter(user, field_name, delta):
    current = getattr(user, field_name) or 0
    setattr(user, field_name, max(0, current + delta))
    user.save(update_fields=[field_name])


# ============================================================
# Recipe / Ingredient / Homework create/delete
# ============================================================

@receiver(post_save, sender=Recipe)
def handle_recipe_post(sender, instance, created, **kwargs):
    if not created:
        return
    UserPost.objects.get_or_create(
        user=instance.author,
        post_type=UserPost.PostType.RECIPE,
        post_id=str(instance.id),
    )
    instance.author.recipe_count += 1
    instance.author.save(update_fields=['recipe_count'])
    instance.author.add_points(
        PointRules.POST_RECIPE,
        'post_recipe',
        instance,
    )


@receiver(post_delete, sender=Recipe)
def delete_recipe_post(sender, instance, **kwargs):
    UserPost.objects.filter(
        user=instance.author,
        post_type=UserPost.PostType.RECIPE,
        post_id=str(instance.id),
    ).delete()
    PointTransaction.objects.filter(
        user=instance.author,
        reason='post_recipe',
        related_type='recipe',
        related_id=str(instance.id),
    ).delete()
    instance.author.recipe_count = max(0, instance.author.recipe_count - 1)
    instance.author.save(update_fields=['recipe_count'])
    instance.author.recompute_points()


@receiver(post_save, sender=IngredientPost)
def handle_ingredient_post(sender, instance, created, **kwargs):
    if not created:
        return
    UserPost.objects.get_or_create(
        user=instance.author,
        post_type=UserPost.PostType.INGREDIENT,
        post_id=str(instance.id),
    )
    instance.author.ingredient_count += 1
    instance.author.save(update_fields=['ingredient_count'])
    instance.author.add_points(
        PointRules.POST_INGREDIENT,
        'post_ingredient',
        instance,
    )


@receiver(post_delete, sender=IngredientPost)
def delete_ingredient_post(sender, instance, **kwargs):
    UserPost.objects.filter(
        user=instance.author,
        post_type=UserPost.PostType.INGREDIENT,
        post_id=str(instance.id),
    ).delete()
    PointTransaction.objects.filter(
        user=instance.author,
        reason='post_ingredient',
        related_type='ingredientpost',
        related_id=str(instance.id),
    ).delete()
    instance.author.ingredient_count = max(0, instance.author.ingredient_count - 1)
    instance.author.save(update_fields=['ingredient_count'])
    instance.author.recompute_points()


@receiver(post_save, sender=Homework)
def handle_homework_post(sender, instance, created, **kwargs):
    if not created:
        return
    UserPost.objects.get_or_create(
        user=instance.user,
        post_type=UserPost.PostType.DISH,
        post_id=str(instance.id),
    )
    instance.user.dish_count += 1
    instance.user.save(update_fields=['dish_count'])
    instance.user.add_points(
        PointRules.UPLOAD_DISH,
        'upload_dish',
        instance,
    )


@receiver(post_delete, sender=Homework)
def delete_homework_post(sender, instance, **kwargs):
    UserPost.objects.filter(
        user=instance.user,
        post_type=UserPost.PostType.DISH,
        post_id=str(instance.id),
    ).delete()
    PointTransaction.objects.filter(
        user=instance.user,
        reason='upload_dish',
        related_type='homework',
        related_id=str(instance.id),
    ).delete()
    instance.user.dish_count = max(0, instance.user.dish_count - 1)
    instance.user.save(update_fields=['dish_count'])
    instance.user.recompute_points()


# ============================================================
# Likes (M2M)
# ============================================================

def _award_on_like(liker, target):
    author = _author_of(target)
    if author is None or author.id == liker.id:
        return

    points, reason = _points_for_like(liker, target)
    if points <= 0:
        return

    key = _like_key(liker, target)
    if PointTransaction.objects.filter(
        user=author,
        reason=reason,
        related_type='like',
        related_id=key,
    ).exists():
        return

    # Profile "likes" counters track real humans (+1 per like).
    field = _counter_field_for(target)
    if field:
        _bump_like_counter(author, field, 1)

    # Points come from transactions.
    PointTransaction.objects.create(
        user=author,
        points=points,
        reason=reason,
        related_type='like',
        related_id=key,
    )
    author.recompute_points()


def _reverse_on_unlike(liker, target):
    author = _author_of(target)
    if author is None:
        return

    key = _like_key(liker, target)
    tx = PointTransaction.objects.filter(
        user=author,
        related_type='like',
        related_id=key,
    ).order_by('-id').first()

    if tx is None:
        return

    field = _counter_field_for(target)
    if field:
        _bump_like_counter(author, field, -1)

    tx.delete()
    author.recompute_points()


@receiver(m2m_changed, sender=Recipe.likes.through)
def recipe_likes_changed(sender, instance, action, pk_set, reverse, **kwargs):
    if reverse or action not in ('post_add', 'post_remove'):
        return
    from users.models import User
    for pk in pk_set or []:
        try:
            liker = User.objects.get(pk=pk)
        except User.DoesNotExist:
            continue
        if action == 'post_add':
            _award_on_like(liker, instance)
        else:
            _reverse_on_unlike(liker, instance)


@receiver(m2m_changed, sender=IngredientPost.likes.through)
def ingredient_likes_changed(sender, instance, action, pk_set, reverse, **kwargs):
    if reverse or action not in ('post_add', 'post_remove'):
        return
    from users.models import User
    for pk in pk_set or []:
        try:
            liker = User.objects.get(pk=pk)
        except User.DoesNotExist:
            continue
        if action == 'post_add':
            _award_on_like(liker, instance)
        else:
            _reverse_on_unlike(liker, instance)


@receiver(m2m_changed, sender=Homework.likes.through)
def homework_likes_changed(sender, instance, action, pk_set, reverse, **kwargs):
    if reverse or action not in ('post_add', 'post_remove'):
        return
    from users.models import User
    for pk in pk_set or []:
        try:
            liker = User.objects.get(pk=pk)
        except User.DoesNotExist:
            continue
        if action == 'post_add':
            _award_on_like(liker, instance)
        else:
            _reverse_on_unlike(liker, instance)