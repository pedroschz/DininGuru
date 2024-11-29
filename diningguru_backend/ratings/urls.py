# ratings/urls.py

from django.urls import path
from .views import (
    submit_rating,
    average_rating,
    fetch_comments,
    submit_or_update_comment,
    like_comment
)

urlpatterns = [
    path('ratings', submit_rating, name='submit_rating'),  # POST /api/ratings
    path('ratings/<int:venue_id>/average', average_rating, name='average_rating'),  # GET /api/ratings/<venue_id>/average
    
    # Comment URLs
    path('comments/<int:venue_id>', fetch_comments, name='fetch_comments'),  # GET /api/comments/<venue_id>?user_id=<user_id>
    path('comments', submit_or_update_comment, name='submit_or_update_comment'),  # POST /api/comments
    path('comments/<int:comment_id>/like', like_comment, name='like_comment'),  # POST /api/comments/<comment_id>/like
]