# ratings/models.py

from django.db import models
from django.contrib.auth.models import User

class Rating(models.Model):
    venue_id = models.IntegerField()
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    rating = models.FloatField()
    meal_period = models.CharField(max_length=20)
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('venue_id', 'user', 'meal_period')  # Ensures one rating per user per venue per meal period

class Comment(models.Model):
    venue_id = models.IntegerField()
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    text = models.TextField()
    meal_period = models.CharField(max_length=20)
    likes = models.ManyToManyField(User, related_name='liked_comments', blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('venue_id', 'user', 'meal_period')  # Ensures one comment per user per venue per meal period

    @property
    def like_count(self):
        return self.likes.count()

    def has_liked(self, user):
        return self.likes.filter(id=user.id).exists()
