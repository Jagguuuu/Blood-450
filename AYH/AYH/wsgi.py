import os
import sys
import logging
from django.core.wsgi import get_wsgi_application

_wsgi_dir = os.path.dirname(os.path.abspath(__file__))
_project_root = os.path.dirname(_wsgi_dir)
if _project_root not in sys.path:
    sys.path.insert(0, _project_root)

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "AYH.settings")

application = get_wsgi_application()
app = application

# On Vercel cold start, apply migrations so missing tables do not cause 500s.
# Failures are logged; they do not crash import if DB is temporarily unreachable.
if os.environ.get("VERCEL"):
    try:
        from django.core.management import call_command

        call_command("migrate", interactive=False, run_syncdb=True, verbosity=0)
    except Exception:
        logging.getLogger(__name__).exception("Vercel cold-start migrate failed")
