# reports/urls.py
from django.urls import path
from . import views

urlpatterns = [
    path('create/', views.ReportCreateView.as_view(), name='report-create'),
    path('', views.ReportListView.as_view(), name='report-list'),
    path('<uuid:report_id>/resolve/', views.ReportResolveView.as_view(), name='report-resolve'),
]