# users/point_rules.py
class PointRules:
    """Point values for user actions."""

    UPLOAD_DISH = 1
    CHEF_LIKE_DISH = 10
    RECEIVE_LIKE = 1
    RECEIVE_LIKE_PRIORITY = 10   # Expert / Official like
    POST_RECIPE = 10
    POST_INGREDIENT = 5

    MENTOR_MIN_LEVEL = 3

    @staticmethod
    def get_reason_display(reason):
        reasons = {
            'upload_dish': 'Upload Dish',
            'chef_like_dish': 'Chef Liked Dish',
            'receive_like': 'Received Like',
            'post_recipe': 'Posted Recipe',
            'post_ingredient': 'Posted Ingredient Guide',
            'admin_adjust': 'Admin Adjust',
            'post_rejected': 'Post Rejected',
        }
        return reasons.get(reason, reason)