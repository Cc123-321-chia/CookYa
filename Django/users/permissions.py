# users/permissions.py
from rest_framework.permissions import BasePermission


class IsAdminPanelUser(BasePermission):
    """
    Allow access only to users marked as staff (admin panel users).
    This works for both:
    - Real User records (is_staff=True)
    - Mirror users created by admin_login (is_staff=True)
    """

    def has_permission(self, request, view):
        return bool(
            request.user
            and request.user.is_authenticated
            and (request.user.is_staff or request.user.is_superuser)
        )