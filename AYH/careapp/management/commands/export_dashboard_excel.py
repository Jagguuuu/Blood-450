import random
from datetime import timedelta
from django.core.management.base import BaseCommand
from django.utils import timezone
from careapp.models import DonorProfile, BloodRequest

class Command(BaseCommand):
    help = "Export Donors and Blood Requests to Excel for Analytics (Power BI) dashboard."

    def add_arguments(self, parser):
        parser.add_argument(
            '--output',
            type=str,
            default='dashboard_export.xlsx',
            help='Output Excel file path (default: dashboard_export.xlsx)',
        )
        parser.add_argument(
            '--sample-rows',
            type=int,
            default=200,
            help='If DB is empty, generate this many sample rows per sheet (default: 200)',
        )

    def handle(self, *args, **options):
        try:
            import pandas as pd
        except ImportError:
            self.stderr.write(self.style.ERROR('Install pandas and openpyxl: pip install pandas openpyxl'))
            return

        out_path = options['output']
        sample_rows = max(50, min(2000, options['sample_rows']))

        # ---- Sheet 1: Blood Requests (used first by dashboard) ----
        requests_qs = BloodRequest.objects.all().order_by('-created_at')[:5000]
        if requests_qs.exists():
            rows = []
            for r in requests_qs:
                rows.append({
                    'request_id': str(r.request_id) if r.request_id else '',
                    'created_at': r.created_at.date() if r.created_at else None,
                    'blood_group': r.blood_group or '',
                    'urgency': r.urgency or '',
                    'status': r.status or '',
                    'city': r.city or '',
                    'state': r.state or '',
                    'source': r.source or '',
                    'units_needed': r.units_needed,
                    'patient_age': r.patient_age,
                    'sla_minutes': r.sla_minutes,
                    'closure_type': r.closure_type or '',
                    'closure_reason': r.closure_reason or '',
                })
            df_requests = pd.DataFrame(rows)
            self.stdout.write(f'Exported {len(rows)} blood requests from database.')
        else:
            df_requests = pd.DataFrame(self._sample_blood_requests(sample_rows))
            self.stdout.write(self.style.WARNING(f'No requests in DB. Generated {len(df_requests)} sample rows.'))

        # ---- Sheet 2: Donors ----
        donors_qs = DonorProfile.objects.select_related('user').order_by('-created_at')[:5000]
        if donors_qs.exists():
            rows = []
            for d in donors_qs:
                rows.append({
                    'donor_id': str(d.donor_id) if d.donor_id else '',
                    'username': d.user.username if d.user_id else '',
                    'blood_group': d.blood_group or '',
                    'city': d.city or '',
                    'is_available': d.is_available,
                    'availability_status': d.availability_status or '',
                    'reliability_score': float(d.reliability_score) if d.reliability_score is not None else None,
                    'created_at': d.created_at.date() if d.created_at else None,
                })
            df_donors = pd.DataFrame(rows)
            self.stdout.write(f'Exported {len(rows)} donors from database.')
        else:
            df_donors = pd.DataFrame(self._sample_donors(sample_rows))
            self.stdout.write(self.style.WARNING(f'No donors in DB. Generated {len(df_donors)} sample rows.'))

        # Write Excel (BloodRequests first so dashboard uses it by default)
        with pd.ExcelWriter(out_path, engine='openpyxl') as writer:
            df_requests.to_excel(writer, sheet_name='BloodRequests', index=False)
            df_donors.to_excel(writer, sheet_name='Donors', index=False)

        self.stdout.write(self.style.SUCCESS(f'Excel saved: {out_path}'))
        self.stdout.write('Upload this file at /analytics/ to view the Power BI-style dashboard.')

    def _sample_blood_requests(self, n):
        blood_groups = [c[0] for c in BloodRequest.BLOOD_GROUP_CHOICES]
        urgencies = [c[0] for c in BloodRequest.URGENCY_CHOICES]
        statuses = [c[0] for c in BloodRequest.STATUS_CHOICES]
        sources = [c[0] for c in BloodRequest.SOURCE_CHOICES]
        closure_types = [c[0] for c in BloodRequest.CLOSURE_TYPE_CHOICES]
        closure_reasons = [c[0] for c in BloodRequest.CLOSURE_REASON_CHOICES]
        cities = ['Bhubaneswar', 'Cuttack', 'Puri', 'Berhampur', 'Rourkela', 'Bangalore', 'Mumbai', 'Delhi']
        states = ['Odisha', 'Karnataka', 'Maharashtra', 'Delhi', 'Tamil Nadu']

        base_date = timezone.now().date()
        rows = []
        for i in range(n):
            created = base_date - timedelta(days=random.randint(0, 365))
            rows.append({
                'request_id': f'req-{1000 + i}',
                'created_at': created,
                'blood_group': random.choice(blood_groups),
                'urgency': random.choice(urgencies),
                'status': random.choice(statuses),
                'city': random.choice(cities),
                'state': random.choice(states),
                'source': random.choice(sources),
                'units_needed': random.randint(1, 4),
                'patient_age': random.randint(1, 80) if random.random() < 0.8 else None,
                'sla_minutes': random.choice([60, 90, 120, 180]) if random.random() < 0.7 else None,
                'closure_type': random.choice(closure_types + ['']),
                'closure_reason': random.choice(closure_reasons + ['']),
            })
        return rows

    def _sample_donors(self, n):
        blood_groups = [c[0] for c in DonorProfile.BLOOD_GROUP_CHOICES]
        cities = ['Bhubaneswar', 'Cuttack', 'Puri', 'Berhampur', 'Rourkela', 'Bangalore', 'Mumbai', 'Delhi']
        statuses = ['Available', 'Busy']

        base_date = timezone.now().date()
        rows = []
        for i in range(n):
            created = base_date - timedelta(days=random.randint(0, 365))
            rows.append({
                'donor_id': f'don-{2000 + i}',
                'username': f'donor_{i}',
                'blood_group': random.choice(blood_groups),
                'city': random.choice(cities),
                'is_available': random.choice([True, False]),
                'availability_status': random.choice(statuses),
                'reliability_score': round(random.uniform(0.5, 1.0), 2) if random.random() < 0.6 else None,
                'created_at': created,
            })
        return rows
