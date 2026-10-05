import os
import sys
import random
import math
from datetime import date, timedelta
from decimal import Decimal
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'AYH.settings')
django.setup()

from django.contrib.auth.models import User
from django.db import transaction
from careapp.models import DonorProfile, UserProfile

# Optional: use Faker for realistic names/locations (pip install Faker)
try:
    from faker import Faker
    FAKER = Faker('en_IN')
    USE_FAKER = True
except ImportError:
    USE_FAKER = False

BLOOD_GROUPS = [bg[0] for bg in DonorProfile.BLOOD_GROUP_CHOICES]
DEFAULT_PASSWORD = 'donor@123'

# For dynamic name generation without fixed lists (used when Faker not installed)
# Full alphabet: all letters can appear in generated names
_CONSONANTS = 'bcdfghjklmnpqrstvwxyz'   # all consonants (excluding vowels a,e,i,o,u)
_VOWELS = 'aeiou'
_LETTERS = 'abcdefghijklmnopqrstuvwxyz'  # all 26 letters


def _random_syllable():
    """One syllable: consonant + vowel, or consonant + vowel + any letter (all 26 can appear)."""
    c1 = random.choice(_CONSONANTS)
    v = random.choice(_VOWELS)
    if random.random() < 0.4:
        return c1 + v + random.choice(_LETTERS)
    return c1 + v


def random_generated_name(syllables_min=2, syllables_max=3):
    """Generate a random name-like word from syllables (no fixed list)."""
    n = random.randint(syllables_min, syllables_max)
    parts = [_random_syllable() for _ in range(n)]
    return ''.join(parts).capitalize()


def random_first_name():
    """Dynamically generated first name."""
    if USE_FAKER:
        return FAKER.first_name()
    return random_generated_name(1, 3)


def random_last_name():
    """Dynamically generated last name."""
    if USE_FAKER:
        return FAKER.last_name()
    return random_generated_name(2, 3)


def random_city_state():
    """Dynamically generated city and state."""
    if USE_FAKER:
        city = FAKER.city()
        state = FAKER.state()
        return city, state
    city = random_generated_name(2, 4) + random.choice(['pur', 'abad', 'nagar', 'garh', ''])
    state = random_generated_name(2, 3) + random.choice([' Pradesh', ' State', ''])
    return city, state


def random_occupation():
    """Dynamically generated occupation."""
    if USE_FAKER:
        return FAKER.job()[:100]
    roles = ['Engineer', 'Analyst', 'Manager', 'Specialist', 'Coordinator', 'Developer', 'Consultant', 'Technician']
    suffix = random_generated_name(1, 2) if random.random() < 0.5 else ''
    return (random.choice(roles) + ' ' + suffix).strip()[:100] or 'Professional'


def random_phone():
    """Generate a unique 10-digit Indian-style mobile number (6/7/8/9 prefix)."""
    prefix = random.choice(['6', '7', '8', '9'])
    rest = ''.join(str(random.randint(0, 9)) for _ in range(9))
    return prefix + rest


def random_username(first_name, last_name, used_usernames):
    base = f"{first_name}_{last_name}".lower().replace(' ', '_')
    base = ''.join(c for c in base if c.isalnum() or c in '._')
    if not base:
        base = 'donor'
    username = base
    counter = 1
    while username in used_usernames:
        username = f"{base}{counter}"
        counter += 1
    used_usernames.add(username)
    return username


def random_date_of_birth():
    """Random DOB between 18 and 65 years ago."""
    years_ago = random.randint(18, 65)
    start = date.today() - timedelta(days=years_ago * 365)
    return start + timedelta(days=random.randint(0, 364))


def random_last_donation():
    """Random last donation date (optional, within last 2 years)."""
    if random.random() < 0.5:
        return None
    days_ago = random.randint(30, 730)
    return date.today() - timedelta(days=days_ago)


# Default center for random distance (when user does not enter lat/lon)
DEFAULT_CENTER_LAT = Decimal('20.296059')
DEFAULT_CENTER_LNG = Decimal('85.824539')

# For donors without user-provided location: random distance from center so active vs standby differ
def random_lat_lng_at_distance_km(center_lat=None, center_lng=None, radius_km_min=0.3, radius_km_max=12.0):
    """Return (lat, lng) at a random distance between radius_km_min and radius_km_max from center (for varied active/standby)."""
    if center_lat is None:
        center_lat = DEFAULT_CENTER_LAT
    if center_lng is None:
        center_lng = DEFAULT_CENTER_LNG
    radius_km = random.uniform(radius_km_min, radius_km_max)
    angle_rad = random.uniform(0, 2 * math.pi)
    # Approx: 1 deg lat ~ 111 km; 1 deg lng ~ 111*cos(lat) km
    lat_rad = math.radians(float(center_lat))
    delta_lat_deg = (radius_km / 111.0) * math.cos(angle_rad)
    delta_lng_deg = (radius_km / (111.0 * math.cos(lat_rad))) * math.sin(angle_rad)
    lat = Decimal(str(round(float(center_lat) + delta_lat_deg, 6)))
    lng = Decimal(str(round(float(center_lng) + delta_lng_deg, 6)))
    return lat, lng


def create_dummy_donor(used_phones, used_usernames, index, shared_lat_lng=None, shared_blood_group=None):
    """Create one dummy User with DonorProfile and UserProfile. All names/locations generated dynamically.
    If shared_lat_lng is (lat, lng), use that location; if shared_blood_group is set, use that blood group."""
    first_name = random_first_name()
    last_name = random_last_name()
    city, state = random_city_state()
    occupation = random_occupation()
    if USE_FAKER:
        area = FAKER.street_name() if random.random() < 0.5 else ''
        pincode = FAKER.postcode()[:6] if random.random() < 0.5 else ''
    else:
        area = random_generated_name(1, 2) if random.random() < 0.3 else ''
        pincode = ''.join(str(random.randint(0, 9)) for _ in range(6))

    phone = random_phone()
    while phone in used_phones:
        phone = random_phone()
    used_phones.add(phone)

    username = random_username(first_name, last_name, used_usernames)
    blood_group = shared_blood_group if shared_blood_group else random.choice(BLOOD_GROUPS)
    display_name = f"{first_name} {last_name}".strip()

    with transaction.atomic():
        user = User.objects.create_user(
            username=username,
            email=f"{username}@dummy.example.com",
            password=DEFAULT_PASSWORD,
            first_name=first_name,
            last_name=last_name,
            is_active=True,
        )
        UserProfile.objects.create(
            user=user,
            gender=random.choice(['M', 'F', 'O', None]),
            date_of_birth=random_date_of_birth(),
            state=state,
            city=city,
            area=area,
            pincode=pincode,
            weight_kg=round(random.uniform(50, 90), 1) if random.random() < 0.7 else None,
            donated_before=random.choice([True, False, None]),
            last_donation_date=random_last_donation(),
            medical_conditions=random.choice([True, False, None]),
            currently_healthy=random.choice([True, False, None]),
            emergency_available=random.choice([True, False]),
            preferred_contact=random.choice(['call', 'whatsapp', 'sms']),
            consent_contact=True,
            consent_terms=True,
            alternate_mobile='',
            preferred_language=random.choice(['english', 'hindi', 'odia', '']),
            preferred_contact_time=random.choice(['morning', 'afternoon', 'evening', 'any', '']),
            occupation=occupation,
            emergency_contact_name='',
            emergency_contact_number='',
        )
        # Location: use shared_lat_lng if provided (from terminal prompt); else random distance from default center
        if shared_lat_lng is not None:
            lat, lng = shared_lat_lng
        else:
            lat, lng = random_lat_lng_at_distance_km()
        DonorProfile.objects.create(
            user=user,
            phone=phone,
            blood_group=blood_group,
            is_available=random.choice([True, False]),
            phone_verified=random.choice([True, False]),
            city=city,
            last_lat=lat,
            last_lng=lng,
            last_donation_date=random_last_donation(),
            availability_status=random.choice(['Available', 'Busy']),
            reliability_score=round(random.uniform(0.5, 1.0), 2) if random.random() < 0.5 else None,
        )
    return {
        'username': username,
        'password': DEFAULT_PASSWORD,
        'name': display_name,
        'phone': phone,
        'blood_group': blood_group,
        'city': city,
    }


def get_count():
    """Get number of donors from command line or prompt (1-500)."""
    if len(sys.argv) > 1:
        try:
            n = int(sys.argv[1])
            if 1 <= n <= 500:
                return n
            print("Please enter a number between 1 and 500.")
        except ValueError:
            print("Usage: python create_dummy_donors.py [count]")
            sys.exit(1)
    while True:
        try:
            raw = input("Enter number of dummy donors to create (1-500): ").strip()
            if not raw:
                raw = "10"
            n = int(raw)
            if 1 <= n <= 500:
                return n
            print("Please enter a number between 1 and 500.")
        except ValueError:
            print("Invalid input. Enter a number between 1 and 500.")
        except EOFError:
            print("No input. Exiting.")
            sys.exit(0)


def prompt_lat_lon_for_batch(start_one_based, end_one_based):
    """Prompt user for latitude and longitude for a batch of donors (e.g. donors 1-5).
    Returns (Decimal(lat), Decimal(lng)) or None if user presses Enter (use random)."""
    print(f"\n  --- Donors {start_one_based} to {end_one_based} ---")
    try:
        lat_str = input(f"  Enter latitude for donors {start_one_based}-{end_one_based} (or press Enter for random): ").strip()
        if not lat_str:
            return None
        lng_str = input(f"  Enter longitude for donors {start_one_based}-{end_one_based} (or press Enter for random): ").strip()
        if not lng_str:
            return None
        lat = Decimal(lat_str.replace(",", "."))
        lng = Decimal(lng_str.replace(",", "."))
        if -90 <= float(lat) <= 90 and -180 <= float(lng) <= 180:
            return (lat, lng)
        print("  Invalid range (lat -90..90, lng -180..180). Using random for this batch.")
        return None
    except Exception as e:
        print(f"  Invalid input ({e}). Using random for this batch.")
        return None


def main():
    count = get_count()

    used_phones = set(DonorProfile.objects.values_list('phone', flat=True))
    used_usernames = set(User.objects.values_list('username', flat=True))

    print(f"Creating {count} dummy donor(s)...")
    print("  Every 5 donors you will be prompted for latitude and longitude (or press Enter for random).")
    created = []
    for i in range(count):
        # Every 5 donors, prompt for lat/lon for this batch
        if i % 5 == 0:
            batch_start = i + 1
            batch_end = min(i + 5, count)
            batch_lat_lng = prompt_lat_lon_for_batch(batch_start, batch_end)
        try:
            donor = create_dummy_donor(
                used_phones, used_usernames, i,
                shared_lat_lng=batch_lat_lng,
                shared_blood_group=None,
            )
            lat_val = float(batch_lat_lng[0]) if batch_lat_lng else None
            lng_val = float(batch_lat_lng[1]) if batch_lat_lng else None
            donor['last_lat'] = lat_val
            donor['last_lng'] = lng_val
            created.append(donor)
            loc_note = f" [lat={batch_lat_lng[0]}, lng={batch_lat_lng[1]}]" if batch_lat_lng else " [random]"
            print(f"  [{i+1}/{count}] {donor['name']} | {donor['username']} | {donor['phone']} | {donor['blood_group']} | {donor['city']}{loc_note}")
        except Exception as e:
            print(f"  [{i+1}/{count}] ERROR: {e}")
            raise

    print(f"\nDone. Created {len(created)} donor(s).")
    print(f"Login with username and password: {DEFAULT_PASSWORD}")
    if created:
        print("\nSample logins (first 3):")
        for d in created[:3]:
            print(f"  {d['username']} / {DEFAULT_PASSWORD}")


if __name__ == '__main__':
    main()
