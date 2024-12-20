# Generated by Django 5.1.3 on 2024-11-30 00:09

import django.utils.timezone
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('ratings', '0003_alter_comment_unique_together_and_more'),
    ]

    operations = [
        migrations.AlterField(
            model_name='comment',
            name='meal_period',
            field=models.CharField(default=django.utils.timezone.now, max_length=20),
            preserve_default=False,
        ),
        migrations.AlterField(
            model_name='rating',
            name='meal_period',
            field=models.CharField(default=django.utils.timezone.now, max_length=20),
            preserve_default=False,
        ),
    ]
