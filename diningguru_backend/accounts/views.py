from django.shortcuts import render, redirect
from django.contrib.auth.tokens import default_token_generator
from django.contrib.auth import get_user_model, login
from django.contrib.sites.shortcuts import get_current_site
from django.utils.http import urlsafe_base64_encode, urlsafe_base64_decode
from django.utils.encoding import force_bytes, force_str
from django.template.loader import render_to_string
from django.core.mail import send_mail
from django.contrib.auth.decorators import login_required
from django.views.decorators.csrf import csrf_exempt
from django.http import JsonResponse
from django.utils import timezone
from datetime import timedelta
import random
import string
import json
from .models import VerificationCode


User = get_user_model()

def send_login_link(request):
    if request.method == 'POST':
        email = request.POST.get('email')
        user = User.objects.get(email=email)

        if user:
            # Generate a one-time use token for the user
            token = default_token_generator.make_token(user)

            # Create a unique link for the user to log in
            uid = urlsafe_base64_encode(force_bytes(user.pk))
            domain = get_current_site(request).domain
            login_link = f'http://{domain}/login/{uid}/{token}/'
            print("login,", login_link)

            # Send the login link via email
            subject = 'Your Login Link'
            message = render_to_string('login_link.html', {'login_link': login_link})
            from_email = 'noreply@example.com'
            send_mail(subject, message, from_email, [email], fail_silently=False)

        return render(request, 'email_sent.html')
    return render(request, 'send_login_link.html')

def login_with_link(request, uidb64, token):
    try:
        uid = force_str(urlsafe_base64_decode(uidb64))
        user = User.objects.get(pk=uid)
    except (TypeError, ValueError, OverflowError, User.DoesNotExist):
        user = None

    if user and default_token_generator.check_token(user, token):
        # Log the user in without requiring a password
        user.backend = 'django.contrib.auth.backends.ModelBackend'
        login(request, user)

        return redirect('user_email')  # Replace 'home' with the URL to redirect after login

    return render(request, 'login_link_invalid.html')

@login_required
def user_email(request):
    email = request.user.email
    return render(request, 'user.html', {'email': email})
    
    
    
    
    
@csrf_exempt
def login_or_signup(request):
    if request.method == 'POST':
        data = json.loads(request.body)
        email = data.get('email')

        if not email:
            return JsonResponse({'error': 'Email is required.'}, status=400)

        user, created = User.objects.get_or_create(email=email, username=email)

        # Generate a 6-digit verification code
        code = ''.join(random.choices(string.digits, k=6))

        # Save the code
        VerificationCode.objects.create(user=user, code=code)

        # Send email with the code (using console backend for development)
        send_mail(
            'DininGuru verification code',  # Updated subject
            '',  # Plain text version (can be left empty if not needed)
            'noreply@example.com',
            [email],
            fail_silently=False,
            html_message=f"""
                <html>
                    <body style="font-family: Arial, sans-serif; line-height: 1.6;">
                        <p style="color: #333;">Yoo, this is Chinmay from DininGuru.</p>
                        <p>Here's your code:</p>
                        <div style="font-size: 24px; font-weight: bold; color: #4CAF50; margin: 20px 0;">
                            {code}
                        </div>
                        <p>Welcome to DininGuru!</p>
                        <p style="color: #888;">If you did not request this code, please ignore this email.</p>
                    </body>
                </html>
            """
        )

        return JsonResponse({'message': 'Verification code sent to your email.'}, status=200)
    else:
        return JsonResponse({'error': 'Invalid request method.'}, status=405)

@csrf_exempt
def verify_code(request):
    if request.method == 'POST':
        data = json.loads(request.body)
        email = data.get('email')
        code = data.get('code')

        if not email or not code:
            return JsonResponse({'error': 'Email and code are required.'}, status=400)

        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            return JsonResponse({'error': 'Invalid email.'}, status=400)

        # Check if code is valid and not expired (10-minute validity)
        now = timezone.now()
        code_validity_period = now - timedelta(minutes=10)

        try:
            verification_code = VerificationCode.objects.filter(
                user=user,
                code=code,
                is_used=False,
                created_at__gte=code_validity_period
            ).latest('created_at')
        except VerificationCode.DoesNotExist:
            return JsonResponse({'error': 'Invalid or expired code.'}, status=400)

        # Mark code as used
        verification_code.is_used = True
        verification_code.save()

        return JsonResponse({'user_id': user.id}, status=200)
    else:
        return JsonResponse({'error': 'Invalid request method.'}, status=405)
