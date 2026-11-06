"""
WSGI config for CookYaBackend project.

It exposes the WSGI callable as a module-level variable named ``application``.

For more information on this file, see
https://docs.djangoproject.com/en/5.2/howto/deployment/wsgi/
"""

import os
from django.core.wsgi import get_wsgi_application
from yyds_mdns import MDNS

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'CookYaBackend.settings')

application = get_wsgi_application()

# 广播服务，让局域网内设备可以通过 http://cookya.local:8000 访问
MDNS(application, name="cookya", port=8000)
