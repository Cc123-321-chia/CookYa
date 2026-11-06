# groceries/serializers.py
from rest_framework import serializers
from .models import GroceryList, GroceryItem


class GroceryItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = GroceryItem
        fields = [
            'id', 'name', 'category', 'quantity', 'unit',
            'is_checked', 'recipe_name', 'added_date'
        ]
        read_only_fields = ['id', 'added_date']


class GroceryListSerializer(serializers.ModelSerializer):
    items = GroceryItemSerializer(many=True, read_only=True)
    total_items = serializers.IntegerField(read_only=True)
    checked_items = serializers.IntegerField(read_only=True)
    progress = serializers.FloatField(read_only=True)
    user_name = serializers.CharField(source='user.username', read_only=True)

    class Meta:
        model = GroceryList
        fields = [
            'id', 'user', 'user_name', 'title', 'shopping_date',
            'is_generated', 'remark', 'created_at', 'updated_at',
            'items', 'total_items', 'checked_items', 'progress'
        ]
        read_only_fields = ['id', 'user', 'created_at', 'updated_at']


class GroceryListCreateSerializer(serializers.ModelSerializer):
    items = GroceryItemSerializer(many=True, required=False)

    class Meta:
        model = GroceryList
        fields = ['id', 'title', 'shopping_date', 'is_generated', 'remark', 'items']
        read_only_fields = ['id']

    def create(self, validated_data):
        items_data = validated_data.pop('items', [])
        request = self.context.get('request')
        validated_data['user'] = request.user

        grocery_list = GroceryList.objects.create(**validated_data)

        for item_data in items_data:
            GroceryItem.objects.create(grocery_list=grocery_list, **item_data)

        return grocery_list


class GroceryItemCreateUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = GroceryItem
        fields = ['id', 'name', 'category', 'quantity', 'unit', 'is_checked', 'recipe_name']
        read_only_fields = ['id']