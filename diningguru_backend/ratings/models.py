# ratings/models.py

from django.db import models
from django.contrib.auth.models import User

class Rating(models.Model):
    venue_id = models.IntegerField()
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    rating = models.FloatField()

    class Meta:
        unique_together = ('venue_id', 'user')  # Prevent duplicate ratings per user per venue

class Comment(models.Model):
    venue_id = models.IntegerField()
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    text = models.TextField()
    likes = models.ManyToManyField(User, related_name='liked_comments', blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        unique_together = ('venue_id', 'user')  # Ensure one comment per user per venue

    @property
    def like_count(self):
        return self.likes.count()

    def has_liked(self, user):
        return self.likes.filter(id=user.id).exists()
