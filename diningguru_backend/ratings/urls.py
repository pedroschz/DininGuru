# ratings/urls.py

from django.urls import path
from .views import (
    submit_rating,
    average_rating,
    fetch_comments,
    submit_or_update_comment,
    like_comment,
    unlike_comment,
    get_all_ratings,
    get_all_comments,
)


urlpatterns = [
    # Ratings URLs
    path('ratings', submit_rating, name='submit_rating'),  # POST /api/ratings
    path('ratings/<int:venue_id>/average', average_rating, name='average_rating'),  # GET /api/ratings/<venue_id>/average

    # Comments URLs
    path('comments/<int:venue_id>', fetch_comments, name='fetch_comments'),  # GET /api/comments/<venue_id>
    path('comments', submit_or_update_comment, name='submit_or_update_comment'),  # POST /api/comments
    path('comments/<int:comment_id>/like/', like_comment, name='like_comment'),
    path('comments/<int:comment_id>/unlike/', unlike_comment, name='unlike_comment'),
    path('ratings/all/', get_all_ratings, name='get_all_ratings'),
    path('comments/all/', get_all_comments, name='get_all_comments'),

]
