import os
import sys
from django.core.wsgi import get_wsgi_application

_wsgi_dir = os.path.dirname(os.path.abspath(__file__))
_project_root = os.path.dirname(_wsgi_dir)
if _project_root not in sys.path:
    sys.path.insert(0, _project_root)

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "AYH.settings")

application = get_wsgi_application()
app = application
