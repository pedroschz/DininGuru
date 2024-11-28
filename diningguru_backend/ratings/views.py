# ratings/views.py

from django.shortcuts import render
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.contrib.auth.models import User
from .models import Rating, Comment
from django.db.models import Avg
import json

@csrf_exempt
def submit_rating(request):
    if request.method == "POST":
        data = json.loads(request.body)
        venue_id = data.get("venue_id")
        user_id = data.get("user_id")
        rating = data.get("rating")
        
        try:
            user = User.objects.get(id=user_id)
            rating_obj, created = Rating.objects.update_or_create(
                venue_id=venue_id, user=user,
                defaults={'rating': rating}
            )
            return JsonResponse({"message": "Rating submitted successfully"}, status=201)
        except User.DoesNotExist:
            return JsonResponse({"error": "User not found"}, status=404)
        except Exception as e:
            return JsonResponse({"error": str(e)}, status=500)


from django.db.models import Avg

def average_rating(request, venue_id):
    if request.method == "GET":
        ratings = Rating.objects.filter(venue_id=venue_id)
        if ratings.exists():
            average = ratings.aggregate(Avg('rating'))['rating__avg']
            return JsonResponse({"averageRating": average}, status=200)
        else:
            return JsonResponse({"averageRating": 0.0}, status=200)

@csrf_exempt
def fetch_comments(request, venue_id):
    """
    Fetch all comments for a specific venue.
    """
    if request.method == "GET":
        user_id = request.GET.get('user_id')  # Optional: to determine if the user has liked each comment
        try:
            user = User.objects.get(id=user_id) if user_id else None
        except User.DoesNotExist:
            user = None

        comments = Comment.objects.filter(venue_id=venue_id).order_by('-created_at')
        comments_data = []
        for comment in comments:
            has_liked = comment.has_liked(user) if user else False
            comments_data.append({
                "id": comment.id,
                "venue_id": comment.venue_id,
                "user_id": comment.user.id,
                "text": comment.text,
                "like_count": comment.like_count,
                "has_liked": has_liked,
                "created_at": comment.created_at.isoformat(),
                "updated_at": comment.updated_at.isoformat(),
            })
        return JsonResponse({"comments": comments_data}, status=200)

@csrf_exempt
def submit_or_update_comment(request):
    """
    Submit a new comment or update an existing comment for a user and venue.
    """
    if request.method == "POST":
        data = json.loads(request.body)
        venue_id = data.get("venue_id")
        user_id = data.get("user_id")
        text = data.get("text")
        
        if not all([venue_id, user_id, text]):
            return JsonResponse({"error": "Missing required fields."}, status=400)
        
        try:
            user = User.objects.get(id=user_id)
            comment, created = Comment.objects.update_or_create(
                venue_id=venue_id, user=user,
                defaults={'text': text}
            )
            return JsonResponse({
                "message": "Comment submitted successfully",
                "comment": {
                    "id": comment.id,
                    "venue_id": comment.venue_id,
                    "user_id": comment.user.id,
                    "text": comment.text,
                    "like_count": comment.like_count,
                    "created_at": comment.created_at.isoformat(),
                    "updated_at": comment.updated_at.isoformat(),
                }
            }, status=201)
        except User.DoesNotExist:
            return JsonResponse({"error": "User not found."}, status=404)
        except Exception as e:
            return JsonResponse({"error": str(e)}, status=500)

@csrf_exempt
def like_comment(request, comment_id):
    """
    Like a specific comment.
    """
    if request.method == "POST":
        data = json.loads(request.body)
        user_id = data.get("user_id")
        
        if not user_id:
            return JsonResponse({"error": "Missing user_id."}, status=400)
        
        try:
            user = User.objects.get(id=user_id)
            comment = Comment.objects.get(id=comment_id)
            if comment.likes.filter(id=user.id).exists():
                return JsonResponse({"message": "You have already liked this comment."}, status=400)
            comment.likes.add(user)
            return JsonResponse({"message": "Comment liked successfully.", "like_count": comment.like_count}, status=200)
        except User.DoesNotExist:
            return JsonResponse({"error": "User not found."}, status=404)
        except Comment.DoesNotExist:
            return JsonResponse({"error": "Comment not found."}, status=404)
        except Exception as e:
            return JsonResponse({"error": str(e)}, status=500)
