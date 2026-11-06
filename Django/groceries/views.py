# groceries/views.py
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.db.models import Q
from .models import GroceryList, GroceryItem
from .serializers import (
    GroceryListSerializer,
    GroceryListCreateSerializer,
    GroceryItemSerializer,
    GroceryItemCreateUpdateSerializer
)


class GroceryListListView(generics.ListCreateAPIView):
    """List all grocery lists for the current user or create a new one"""
    permission_classes = [permissions.IsAuthenticated]

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return GroceryListCreateSerializer
        return GroceryListSerializer

    def get_queryset(self):
        return GroceryList.objects.filter(user=self.request.user).order_by('-created_at')

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class GroceryListDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Retrieve, update or delete a grocery list"""
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = GroceryListSerializer
    lookup_field = 'id'

    def get_queryset(self):
        return GroceryList.objects.filter(user=self.request.user)

    def update(self, request, *args, **kwargs):
        instance = self.get_object()
        serializer = GroceryListCreateSerializer(instance, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)

        # Handle items if provided
        items_data = request.data.get('items', None)
        if items_data is not None:
            # Clear existing items and create new ones
            instance.items.all().delete()
            for item_data in items_data:
                GroceryItem.objects.create(grocery_list=instance, **item_data)

        # Update list fields
        if 'title' in request.data:
            instance.title = request.data['title']
        if 'shopping_date' in request.data:
            instance.shopping_date = request.data['shopping_date']
        if 'is_generated' in request.data:
            instance.is_generated = request.data['is_generated']

        instance.save()

        response_serializer = GroceryListSerializer(instance)
        return Response(response_serializer.data)


class GroceryItemCreateView(generics.CreateAPIView):
    """Create a new grocery item in a list"""
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = GroceryItemCreateUpdateSerializer

    def create(self, request, *args, **kwargs):
        list_id = self.kwargs.get('list_id')
        try:
            grocery_list = GroceryList.objects.get(id=list_id, user=request.user)
        except GroceryList.DoesNotExist:
            return Response(
                {'error': 'Grocery list not found'},
                status=status.HTTP_404_NOT_FOUND
            )

        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save(grocery_list=grocery_list)

        return Response(serializer.data, status=status.HTTP_201_CREATED)


class GroceryItemUpdateView(generics.RetrieveUpdateDestroyAPIView):
    """Update or delete a grocery item"""
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = GroceryItemCreateUpdateSerializer
    lookup_field = 'id'

    def get_queryset(self):
        return GroceryItem.objects.filter(grocery_list__user=self.request.user)


class GroceryItemToggleCheckView(APIView):
    """Toggle the checked status of a grocery item"""
    permission_classes = [permissions.IsAuthenticated]

    def patch(self, request, item_id):
        try:
            item = GroceryItem.objects.get(id=item_id, grocery_list__user=request.user)
        except GroceryItem.DoesNotExist:
            return Response(
                {'error': 'Item not found'},
                status=status.HTTP_404_NOT_FOUND
            )

        item.is_checked = not item.is_checked
        item.save()

        serializer = GroceryItemSerializer(item)
        return Response(serializer.data)


class GroceryItemBulkUpdateView(APIView):
    """Bulk update items (e.g., reset all checked status)"""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, list_id):
        try:
            grocery_list = GroceryList.objects.get(id=list_id, user=request.user)
        except GroceryList.DoesNotExist:
            return Response(
                {'error': 'Grocery list not found'},
                status=status.HTTP_404_NOT_FOUND
            )

        action = request.data.get('action', '')

        if action == 'reset_all':
            grocery_list.items.all().update(is_checked=False)
        elif action == 'check_all':
            grocery_list.items.all().update(is_checked=True)
        elif action == 'delete_checked':
            grocery_list.items.filter(is_checked=True).delete()
        else:
            return Response(
                {'error': 'Invalid action'},
                status=status.HTTP_400_BAD_REQUEST
            )

        serializer = GroceryListSerializer(grocery_list)
        return Response(serializer.data)


class GroceryListFromMealPlanView(APIView):
    """Create a grocery list from a meal plan"""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        meal_plan = request.data.get('meal_plan', {})
        title = request.data.get('title', 'Generated Shopping List')
        shopping_date = request.data.get('shopping_date')

        if not meal_plan:
            return Response(
                {'error': 'Meal plan is required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Create grocery list
        grocery_list = GroceryList.objects.create(
            user=request.user,
            title=title,
            shopping_date=shopping_date or timezone.now().date(),
            is_generated=True
        )

        # Parse meal plan and create items
        items_created = []
        for day, meals in meal_plan.items():
            for meal_type, recipes in meals.items():
                for recipe_name in recipes:
                    # This would be expanded to use actual recipe ingredients
                    # For now, we create a placeholder item
                    if recipe_name and recipe_name.strip():
                        item = GroceryItem.objects.create(
                            grocery_list=grocery_list,
                            name=f"Items for {recipe_name}",
                            category='Others',
                            quantity=1,
                            unit='pcs',
                            recipe_name=recipe_name
                        )
                        items_created.append(item)

        serializer = GroceryListSerializer(grocery_list)
        return Response(serializer.data, status=status.HTTP_201_CREATED)