-- Home Service Booking Platform schema for Supabase PostgreSQL.

BEGIN;

CREATE TABLE public.provinces (
  "provinceId" VARCHAR(2) PRIMARY KEY,
  name VARCHAR(150) NOT NULL
);

CREATE TABLE public.wards (
  ward_id VARCHAR(8) PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  "provinceId" VARCHAR(2) NOT NULL REFERENCES public.provinces("provinceId") ON UPDATE CASCADE
);

CREATE TABLE public.users (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name VARCHAR(100) NOT NULL,
  phone_number VARCHAR(20) UNIQUE NOT NULL,
  role VARCHAR(20) NOT NULL CHECK (role IN ('customer', 'provider', 'admin')),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE public.customer_profiles (
  customer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES public.users(user_id) ON DELETE CASCADE,
  default_address TEXT,
  ward_id VARCHAR(8) NOT NULL REFERENCES public.wards(ward_id),
  latitude NUMERIC(10,8),
  longitude NUMERIC(11,8),
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
  CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180)
);

CREATE TABLE public.provider_profiles (
  provider_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES public.users(user_id) ON DELETE CASCADE,
  info TEXT,
  id_card_number VARCHAR(20) UNIQUE,
  avatar_url VARCHAR(255),
  verification_status VARCHAR(20) NOT NULL DEFAULT 'pending'
    CHECK (verification_status IN ('pending', 'verified', 'rejected')),
  average_rating NUMERIC(3,2) NOT NULL DEFAULT 0 CHECK (average_rating BETWEEN 0 AND 5),
  total_reviews INT NOT NULL DEFAULT 0 CHECK (total_reviews >= 0),
  latitude NUMERIC(10,8),
  longitude NUMERIC(11,8),
  is_available_online BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
  CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180)
);

CREATE TABLE public.service_categories (
  category_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id UUID REFERENCES public.service_categories(category_id),
  category_name VARCHAR(100) NOT NULL,
  slug VARCHAR(120) UNIQUE NOT NULL,
  description TEXT,
  icon_url VARCHAR(255),
  status BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE public.services (
  service_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id UUID NOT NULL REFERENCES public.service_categories(category_id),
  title VARCHAR(150) NOT NULL,
  description TEXT,
  price NUMERIC(10,2) NOT NULL CHECK (price >= 0),
  pricing_type VARCHAR(10) NOT NULL CHECK (pricing_type IN ('fixed', 'hourly', 'persquare')),
  estimated_duration INT NOT NULL CHECK (estimated_duration > 0),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE public.provider_services (
  id_pro_ser UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id UUID NOT NULL REFERENCES public.provider_profiles(provider_id) ON DELETE CASCADE,
  service_id UUID NOT NULL REFERENCES public.services(service_id) ON DELETE CASCADE,
  UNIQUE (provider_id, service_id)
);

CREATE TABLE public.provider_areas (
  area_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id UUID NOT NULL REFERENCES public.provider_profiles(provider_id) ON DELETE CASCADE,
  ward_id VARCHAR(8) NOT NULL REFERENCES public.wards(ward_id),
  UNIQUE (provider_id, ward_id)
);

CREATE TABLE public.availability_schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id UUID NOT NULL REFERENCES public.provider_profiles(provider_id) ON DELETE CASCADE,
  day_of_week SMALLINT NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (end_time > start_time),
  UNIQUE (provider_id, day_of_week, start_time, end_time)
);

CREATE TABLE public.availability_exceptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id UUID NOT NULL REFERENCES public.provider_profiles(provider_id) ON DELETE CASCADE,
  exception_date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (end_time > start_time)
);

CREATE TABLE public.bookings (
  booking_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES public.customer_profiles(customer_id),
  provider_id UUID NOT NULL REFERENCES public.provider_profiles(provider_id),
  service_id UUID NOT NULL REFERENCES public.services(service_id),
  scheduled_time TIMESTAMPTZ NOT NULL,
  address TEXT NOT NULL,
  ward_id VARCHAR(8) NOT NULL REFERENCES public.wards(ward_id),
  latitude NUMERIC(10,8),
  longitude NUMERIC(11,8),
  total_incidental NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (total_incidental >= 0),
  total_amount NUMERIC(10,2) NOT NULL CHECK (total_amount >= 0),
  status VARCHAR(20) NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'confirmed', 'in_progress', 'completed', 'cancelled', 'rejected', 'auto_cancelled')),
  payment_status VARCHAR(10) NOT NULL DEFAULT 'unpaid'
    CHECK (payment_status IN ('unpaid', 'paid', 'refunded')),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE public.booking_status_history (
  history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES public.bookings(booking_id) ON DELETE CASCADE,
  previous_status VARCHAR(50),
  new_status VARCHAR(50) NOT NULL,
  changed_by UUID NOT NULL REFERENCES public.users(user_id),
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE public.reviews (
  review_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL UNIQUE REFERENCES public.bookings(booking_id),
  customer_id UUID NOT NULL REFERENCES public.customer_profiles(customer_id),
  provider_id UUID NOT NULL REFERENCES public.provider_profiles(provider_id),
  rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE public.favorites (
  favorite_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES public.customer_profiles(customer_id) ON DELETE CASCADE,
  service_id UUID NOT NULL REFERENCES public.services(service_id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (customer_id, service_id)
);

CREATE TABLE public.support_tickets (
  ticket_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(user_id),
  booking_id UUID REFERENCES public.bookings(booking_id),
  subject VARCHAR(200) NOT NULL,
  content TEXT NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')),
  priority VARCHAR(10) NOT NULL DEFAULT 'medium'
    CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE public.notifications (
  notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id UUID NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
  booking_id UUID REFERENCES public.bookings(booking_id) ON DELETE CASCADE,
  ticket_id UUID REFERENCES public.support_tickets(ticket_id) ON DELETE CASCADE,
  notification_type VARCHAR(40) NOT NULL CHECK (notification_type IN (
    'new_booking_request',
    'booking_accepted',
    'booking_rejected',
    'booking_cancelled',
    'booking_auto_expired',
    'booking_status_changed',
    'review_reminder',
    'support_ticket_response',
    'provider_approval_result',
    'account_suspension'
  )),
  channel VARCHAR(10) NOT NULL CHECK (channel IN ('in_app', 'email')),
  title VARCHAR(200) NOT NULL,
  message TEXT NOT NULL,
  is_read BOOLEAN NOT NULL DEFAULT false,
  read_at TIMESTAMPTZ,
  delivery_status VARCHAR(10) NOT NULL DEFAULT 'pending'
    CHECK (delivery_status IN ('pending', 'sent', 'failed')),
  delivery_attempts INT NOT NULL DEFAULT 0 CHECK (delivery_attempts >= 0),
  last_delivery_error TEXT,
  deduplication_key VARCHAR(255) NOT NULL UNIQUE,
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (
    (is_read = false AND read_at IS NULL)
    OR (is_read = true AND read_at IS NOT NULL)
  ),
  CHECK (
    (
      notification_type IN (
        'new_booking_request',
        'booking_accepted',
        'booking_rejected',
        'booking_cancelled',
        'booking_auto_expired',
        'booking_status_changed',
        'review_reminder'
      )
      AND booking_id IS NOT NULL
      AND ticket_id IS NULL
    )
    OR (
      notification_type = 'support_ticket_response'
      AND ticket_id IS NOT NULL
      AND booking_id IS NULL
    )
    OR (
      notification_type IN ('provider_approval_result', 'account_suspension')
      AND booking_id IS NULL
      AND ticket_id IS NULL
    )
  )
);

CREATE INDEX idx_ward_province ON public.wards("provinceId");
CREATE INDEX idx_services_category ON public.services(category_id);
CREATE INDEX idx_provider_services_service ON public.provider_services(service_id);
CREATE INDEX idx_provider_areas_provider ON public.provider_areas(provider_id);
CREATE INDEX idx_bookings_customer ON public.bookings(customer_id, created_at DESC);
CREATE INDEX idx_bookings_provider ON public.bookings(provider_id, scheduled_time);
CREATE INDEX idx_booking_status_history_booking ON public.booking_status_history(booking_id, created_at);
CREATE INDEX idx_support_tickets_user ON public.support_tickets(user_id, status);
CREATE INDEX idx_notifications_recipient ON public.notifications(recipient_id, created_at DESC);
CREATE INDEX idx_notifications_delivery ON public.notifications(delivery_status, created_at);

CREATE OR REPLACE FUNCTION public.set_schema_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;

CREATE TRIGGER customer_profiles_updated_at BEFORE UPDATE ON public.customer_profiles
FOR EACH ROW EXECUTE FUNCTION public.set_schema_updated_at();
CREATE TRIGGER provider_profiles_updated_at BEFORE UPDATE ON public.provider_profiles
FOR EACH ROW EXECUTE FUNCTION public.set_schema_updated_at();
CREATE TRIGGER users_updated_at BEFORE UPDATE ON public.users
FOR EACH ROW EXECUTE FUNCTION public.set_schema_updated_at();
CREATE TRIGGER services_updated_at BEFORE UPDATE ON public.services
FOR EACH ROW EXECUTE FUNCTION public.set_schema_updated_at();
CREATE TRIGGER bookings_updated_at BEFORE UPDATE ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.set_schema_updated_at();
CREATE TRIGGER support_tickets_updated_at BEFORE UPDATE ON public.support_tickets
FOR EACH ROW EXECUTE FUNCTION public.set_schema_updated_at();

ALTER TABLE public.provinces ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_areas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.availability_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.availability_exceptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY province_read ON public.provinces FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY ward_read ON public.wards FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY service_categories_read ON public.service_categories FOR SELECT TO anon, authenticated USING (status);
CREATE POLICY services_read ON public.services FOR SELECT TO anon, authenticated USING (is_active);

COMMIT;
