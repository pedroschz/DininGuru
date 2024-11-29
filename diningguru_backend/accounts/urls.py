

from django.urls import path, include
from django.conf import settings
from . import views
from django.conf.urls.static import static
 
urlpatterns = [
    path('send-login-link/', views.send_login_link, name='send_login_link'),
    path('login/<str:uidb64>/<str:token>/', views.login_with_link, name='login_with_link'),
    path('user-email/', views.user_email, name='user_email'),
]
