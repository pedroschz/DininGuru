# ratings/views.py

from django.shortcuts import render
from django.views.decorators.http import require_POST
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.contrib.auth.models import User
from .models import Rating, Comment
from django.db.models import Avg
import json
import logging
from django.core.exceptions import ValidationError
from django.core.paginator import Paginator
from django.db.models import Q

logger = logging.getLogger(__name__)



def get_all_ratings(request):
    if request.method == "GET":
        # Fetch query parameters
        user_id = request.GET.get('user_id')
        venue_id = request.GET.get('venue_id')
        meal_period = request.GET.get('meal_period')
        start_date = request.GET.get('start_date')
        end_date = request.GET.get('end_date')
        page_number = request.GET.get('page', 1)
        page_size = request.GET.get('page_size', 50)

        # Build filters
        filters = Q()
        if user_id:
            filters &= Q(user_id=user_id)
        if venue_id:
            filters &= Q(venue_id=venue_id)
        if meal_period:
            filters &= Q(meal_period__iexact=meal_period)
        if start_date and end_date:
            filters &= Q(timestamp__range=[start_date, end_date])
        elif start_date:
            filters &= Q(timestamp__gte=start_date)
        elif end_date:
            filters &= Q(timestamp__lte=end_date)

        # Query and paginate
        ratings = Rating.objects.filter(filters).order_by('-timestamp')
        paginator = Paginator(ratings, page_size)
        page_obj = paginator.get_page(page_number)

        # Serialize data
        ratings_data = list(page_obj.object_list.values())

        # Response
        return JsonResponse({
            'ratings': ratings_data,
            'total_ratings': paginator.count,
            'num_pages': paginator.num_pages,
            'current_page': page_obj.number
        }, status=200)
    else:
        return JsonResponse({'error': 'Invalid request method.'}, status=405)


def get_all_comments(request):
    if request.method == "GET":
        # Fetch query parameters
        user_id = request.GET.get('user_id')
        venue_id = request.GET.get('venue_id')
        meal_period = request.GET.get('meal_period')
        start_date = request.GET.get('start_date')
        end_date = request.GET.get('end_date')
        page_number = request.GET.get('page', 1)
        page_size = request.GET.get('page_size', 50)

        # Build filters
        filters = Q()
        if user_id:
            filters &= Q(user_id=user_id)
        if venue_id:
            filters &= Q(venue_id=venue_id)
        if meal_period:
            filters &= Q(meal_period=meal_period)
        if start_date and end_date:
            filters &= Q(created_at__range=[start_date, end_date])
        elif start_date:
            filters &= Q(created_at__gte=start_date)
        elif end_date:
            filters &= Q(created_at__lte=end_date)

        # Query and paginate
        comments = Comment.objects.filter(filters).order_by('-created_at')
        paginator = Paginator(comments, page_size)
        page_obj = paginator.get_page(page_number)

        # Serialize data
        comments_data = []
        for comment in page_obj.object_list:
            comments_data.append({
                "id": comment.id,
                "venue_id": comment.venue_id,
                "user_id": comment.user.id,
                "meal_period": comment.meal_period,  # Include meal_period
                "text": comment.text,
                "like_count": comment.like_count,
                "created_at": comment.created_at.isoformat(),
                "updated_at": comment.updated_at.isoformat(),
            })

        # Response
        return JsonResponse({
            'comments': comments_data,
            'total_comments': paginator.count,
            'num_pages': paginator.num_pages,
            'current_page': page_obj.number
        }, status=200)
    else:
        return JsonResponse({'error': 'Invalid request method.'}, status=405)
        
        

@csrf_exempt
@require_POST
def submit_rating(request):
    try:
        data = json.loads(request.body)
        venue_id = data.get("venue_id")
        user_id = data.get("user_id")
        rating = data.get("rating")
        meal_period = data.get("meal_period")
        
        meal_period = meal_period.lower()  # Normalize to lowercase

        
        # Log the received data
        logger.debug(f"Received rating submission: venue_id={venue_id}, user_id={user_id}, rating={rating}, meal_period={meal_period}")
        
        # Explicitly convert rating to float
        rating = float(rating)
    except (ValueError, TypeError) as e:
        logger.error(f"Invalid rating value: {e}")
        return JsonResponse({"error": "Invalid rating value."}, status=400)
    
    # Check for missing fields (allow 0.0)
    if venue_id is None or user_id is None or meal_period is None:
        logger.error("Missing required fields.")
        return JsonResponse({"error": "Missing required fields."}, status=400)
    
    try:
        user = User.objects.get(id=user_id)
        rating_obj, created = Rating.objects.update_or_create(
            venue_id=venue_id, user=user, meal_period=meal_period,
            defaults={'rating': rating}
        )
        logger.info(f"Rating submitted successfully by user {user_id} for venue {venue_id}.")
        return JsonResponse({"message": "Rating submitted successfully"}, status=201)
    except User.DoesNotExist:
        logger.error("User not found.")
        return JsonResponse({"error": "User not found"}, status=404)
    except ValidationError as ve:
        logger.error(f"Validation error: {ve}")
        return JsonResponse({"error": str(ve)}, status=400)
    except Exception as e:
        logger.exception(f"Unexpected error: {e}")
        return JsonResponse({"error": str(e)}, status=500)





from django.db.models import Avg

def average_rating(request, venue_id):
    if request.method == "GET":
        meal_period = request.GET.get('meal_period')
        if not meal_period:
            return JsonResponse({"error": "Missing meal_period."}, status=400)
        ratings = Rating.objects.filter(venue_id=venue_id, meal_period=meal_period)
        average = ratings.aggregate(Avg('rating'))['rating__avg'] or 0.0
        count = ratings.count()
        return JsonResponse({"averageRating": average, "reviewCount": count}, status=200)


def fetch_comments(request, venue_id):
    if request.method == "GET":
        user_id = request.GET.get('user_id')
        meal_period = request.GET.get('meal_period')
        if not meal_period:
            return JsonResponse({"error": "Missing meal_period."}, status=400)
        
        try:
            user = User.objects.get(id=user_id) if user_id else None
        except User.DoesNotExist:
            user = None

        comments = Comment.objects.filter(venue_id=venue_id, meal_period=meal_period).order_by('-created_at')
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
    if request.method == "POST":
        data = json.loads(request.body)
        venue_id = data.get("venue_id")
        user_id = data.get("user_id")
        text = data.get("text")
        meal_period = data.get("meal_period")
        
        if not all([venue_id, user_id, text, meal_period]):
            return JsonResponse({"error": "Missing required fields."}, status=400)
            
        meal_period = meal_period.lower()  # Normalize to lowercase

        try:
            user = User.objects.get(id=user_id)
            comment, created = Comment.objects.update_or_create(
                venue_id=venue_id, user=user, meal_period=meal_period,
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



@csrf_exempt
@require_POST
def unlike_comment(request, comment_id):
    """
    Unlike a specific comment.
    """
    try:
        data = json.loads(request.body)
        user_id = data.get("user_id")

        if not user_id:
            return JsonResponse({"error": "Missing user_id."}, status=400)

        user = User.objects.get(id=user_id)
        comment = Comment.objects.get(id=comment_id)

        if not comment.likes.filter(id=user.id).exists():
            return JsonResponse({"message": "You have not liked this comment."}, status=400)

        comment.likes.remove(user)
        return JsonResponse({"message": "Comment unliked successfully.", "like_count": comment.like_count}, status=200)

    except User.DoesNotExist:
        return JsonResponse({"error": "User not found."}, status=404)
    except Comment.DoesNotExist:
        return JsonResponse({"error": "Comment not found."}, status=404)
    except json.JSONDecodeError:
        return JsonResponse({"error": "Invalid JSON."}, status=400)
    except Exception as e:
        return JsonResponse({"error": str(e)}, status=500)
