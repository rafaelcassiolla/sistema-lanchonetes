CREATE SCHEMA IF NOT EXISTS private AUTHORIZATION postgres;

REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated, service_role;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL ON TABLES FROM PUBLIC, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL ON SEQUENCES FROM PUBLIC, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL ON FUNCTIONS FROM PUBLIC, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA private
  REVOKE ALL ON TABLES FROM PUBLIC, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA private
  REVOKE ALL ON SEQUENCES FROM PUBLIC, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA private
  REVOKE ALL ON FUNCTIONS FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA private
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA private
  FROM PUBLIC, anon, authenticated, service_role;

CREATE FUNCTION private.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
  NEW.updated_at = pg_catalog.clock_timestamp();
  RETURN NEW;
END;
$$;

CREATE TABLE public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE RESTRICT,
  display_name text NOT NULL
    CHECK (length(trim(display_name)) BETWEEN 1 AND 100),
  phone text NULL
    CHECK (phone IS NULL OR length(phone) <= 32),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.establishments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL
    CHECK (length(trim(name)) BETWEEN 1 AND 160),
  slug text NOT NULL
    CHECK (
      slug = lower(slug)
      AND slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'
    ),
  timezone text NOT NULL DEFAULT 'America/Sao_Paulo',
  contact_phone text NULL
    CHECK (contact_phone IS NULL OR length(contact_phone) <= 32),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'suspended', 'archived')),
  suspended_at timestamptz NULL,
  archived_at timestamptz NULL,
  created_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT establishments_slug_unique UNIQUE (slug),
  CONSTRAINT establishments_status_timestamps_check CHECK (
    (status = 'active' AND suspended_at IS NULL AND archived_at IS NULL)
    OR (status = 'suspended' AND suspended_at IS NOT NULL AND archived_at IS NULL)
    OR (status = 'archived' AND archived_at IS NOT NULL)
  )
);

CREATE TABLE public.memberships (
  establishment_id uuid NOT NULL
    REFERENCES public.establishments(id) ON DELETE RESTRICT,
  user_id uuid NOT NULL
    REFERENCES public.profiles(id) ON DELETE RESTRICT,
  role text NOT NULL CHECK (role IN ('manager', 'employee')),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'disabled')),
  invited_by_user_id uuid NULL,
  disabled_at timestamptz NULL,
  disabled_by_user_id uuid NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT memberships_pkey PRIMARY KEY (establishment_id, user_id),
  CONSTRAINT memberships_invited_by_fk
    FOREIGN KEY (establishment_id, invited_by_user_id)
    REFERENCES public.memberships(establishment_id, user_id)
    ON DELETE RESTRICT,
  CONSTRAINT memberships_disabled_by_fk
    FOREIGN KEY (establishment_id, disabled_by_user_id)
    REFERENCES public.memberships(establishment_id, user_id)
    ON DELETE RESTRICT,
  CONSTRAINT memberships_status_actor_check CHECK (
    (status = 'active' AND disabled_at IS NULL AND disabled_by_user_id IS NULL)
    OR (
      status = 'disabled'
      AND disabled_at IS NOT NULL
      AND disabled_by_user_id IS NOT NULL
    )
  )
);

CREATE INDEX memberships_user_id_idx ON public.memberships (user_id);

CREATE TABLE public.staff_invitations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  establishment_id uuid NOT NULL
    REFERENCES public.establishments(id) ON DELETE RESTRICT,
  email text NOT NULL
    CHECK (email <> '' AND email = lower(btrim(email))),
  role text NOT NULL CHECK (role IN ('manager', 'employee')),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'accepted', 'revoked', 'expired')),
  invited_by_user_id uuid NOT NULL,
  accepted_user_id uuid NULL
    REFERENCES public.profiles(id) ON DELETE RESTRICT,
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '7 days'),
  accepted_at timestamptz NULL,
  revoked_at timestamptz NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT staff_invitations_inviter_fk
    FOREIGN KEY (establishment_id, invited_by_user_id)
    REFERENCES public.memberships(establishment_id, user_id)
    ON DELETE RESTRICT,
  CONSTRAINT staff_invitations_expiration_check
    CHECK (expires_at > created_at),
  CONSTRAINT staff_invitations_status_fields_check CHECK (
    (
      status = 'accepted'
      AND accepted_user_id IS NOT NULL
      AND accepted_at IS NOT NULL
      AND revoked_at IS NULL
    )
    OR (
      status = 'revoked'
      AND accepted_user_id IS NULL
      AND accepted_at IS NULL
      AND revoked_at IS NOT NULL
    )
    OR (
      status IN ('pending', 'expired')
      AND accepted_user_id IS NULL
      AND accepted_at IS NULL
      AND revoked_at IS NULL
    )
  )
);

CREATE UNIQUE INDEX staff_invitations_pending_email_unique
  ON public.staff_invitations (establishment_id, lower(email))
  WHERE status = 'pending';
CREATE INDEX staff_invitations_status_expiration_idx
  ON public.staff_invitations (establishment_id, status, expires_at);

CREATE TABLE public.dining_tables (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  establishment_id uuid NOT NULL
    REFERENCES public.establishments(id) ON DELETE RESTRICT,
  label text NOT NULL
    CHECK (label <> '' AND label = btrim(label)),
  location text NULL
    CHECK (location IS NULL OR length(location) <= 160),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'disabled')),
  disabled_at timestamptz NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT dining_tables_establishment_id_unique
    UNIQUE (establishment_id, id),
  CONSTRAINT dining_tables_status_timestamp_check CHECK (
    (status = 'active' AND disabled_at IS NULL)
    OR (status = 'disabled' AND disabled_at IS NOT NULL)
  )
);

CREATE UNIQUE INDEX dining_tables_label_unique
  ON public.dining_tables (establishment_id, lower(label));

CREATE TABLE private.table_qr_credentials (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  establishment_id uuid NOT NULL,
  dining_table_id uuid NOT NULL,
  token_hash bytea NOT NULL
    CHECK (octet_length(token_hash) = 32),
  version integer NOT NULL CHECK (version > 0),
  issued_at timestamptz NOT NULL DEFAULT now(),
  revoked_at timestamptz NULL,
  created_by_user_id uuid NULL,
  CONSTRAINT table_qr_credentials_table_fk
    FOREIGN KEY (establishment_id, dining_table_id)
    REFERENCES public.dining_tables(establishment_id, id)
    ON DELETE RESTRICT,
  CONSTRAINT table_qr_credentials_creator_fk
    FOREIGN KEY (establishment_id, created_by_user_id)
    REFERENCES public.memberships(establishment_id, user_id)
    ON DELETE RESTRICT,
  CONSTRAINT table_qr_credentials_table_version_unique
    UNIQUE (establishment_id, dining_table_id, version),
  CONSTRAINT table_qr_credentials_hash_unique UNIQUE (token_hash)
);

CREATE UNIQUE INDEX table_qr_credentials_active_table_unique
  ON private.table_qr_credentials (establishment_id, dining_table_id)
  WHERE revoked_at IS NULL;

CREATE TABLE public.guest_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  establishment_id uuid NOT NULL,
  dining_table_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'closed', 'expired')),
  started_at timestamptz NOT NULL DEFAULT now(),
  last_activity_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '30 minutes'),
  max_expires_at timestamptz NOT NULL DEFAULT (now() + interval '4 hours'),
  ended_at timestamptz NULL,
  closed_by_user_id uuid NULL,
  CONSTRAINT guest_sessions_establishment_id_unique
    UNIQUE (establishment_id, id),
  CONSTRAINT guest_sessions_table_fk
    FOREIGN KEY (establishment_id, dining_table_id)
    REFERENCES public.dining_tables(establishment_id, id)
    ON DELETE RESTRICT,
  CONSTRAINT guest_sessions_closed_by_fk
    FOREIGN KEY (establishment_id, closed_by_user_id)
    REFERENCES public.memberships(establishment_id, user_id)
    ON DELETE RESTRICT,
  CONSTRAINT guest_sessions_time_bounds_check CHECK (
    started_at <= last_activity_at
    AND started_at <= expires_at
    AND expires_at <= max_expires_at
    AND max_expires_at <= started_at + interval '4 hours'
    AND (ended_at IS NULL OR ended_at >= started_at)
  ),
  CONSTRAINT guest_sessions_status_fields_check CHECK (
    (status = 'active' AND ended_at IS NULL AND closed_by_user_id IS NULL)
    OR (
      status = 'closed'
      AND ended_at IS NOT NULL
      AND closed_by_user_id IS NOT NULL
    )
    OR (
      status = 'expired'
      AND ended_at IS NOT NULL
      AND closed_by_user_id IS NULL
    )
  )
);

CREATE UNIQUE INDEX guest_sessions_one_active_per_table
  ON public.guest_sessions (establishment_id, dining_table_id)
  WHERE status = 'active';
CREATE INDEX guest_sessions_active_expiration_idx
  ON public.guest_sessions (expires_at)
  WHERE status = 'active';
CREATE INDEX guest_sessions_tenant_status_started_idx
  ON public.guest_sessions (establishment_id, status, started_at DESC);

CREATE TABLE public.guest_session_clients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  establishment_id uuid NOT NULL,
  guest_session_id uuid NOT NULL,
  auth_user_id uuid NULL
    REFERENCES auth.users(id) ON DELETE SET NULL,
  linked_at timestamptz NOT NULL DEFAULT now(),
  last_seen_at timestamptz NOT NULL DEFAULT now(),
  revoked_at timestamptz NULL,
  CONSTRAINT guest_session_clients_session_fk
    FOREIGN KEY (establishment_id, guest_session_id)
    REFERENCES public.guest_sessions(establishment_id, id)
    ON DELETE RESTRICT,
  CONSTRAINT guest_session_clients_establishment_session_id_unique
    UNIQUE (establishment_id, guest_session_id, id)
);

CREATE UNIQUE INDEX guest_session_clients_one_active_user_unique
  ON public.guest_session_clients (
    establishment_id,
    guest_session_id,
    auth_user_id
  )
  WHERE auth_user_id IS NOT NULL AND revoked_at IS NULL;
CREATE INDEX guest_session_clients_auth_user_idx
  ON public.guest_session_clients (auth_user_id)
  WHERE auth_user_id IS NOT NULL;

CREATE TABLE public.service_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  establishment_id uuid NOT NULL,
  guest_session_id uuid NOT NULL,
  guest_session_client_id uuid NOT NULL,
  type text NOT NULL CHECK (type IN ('waiter', 'bill', 'help')),
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'in_progress', 'resolved', 'cancelled')),
  description text NULL
    CHECK (description IS NULL OR length(description) <= 500),
  assigned_to_user_id uuid NULL,
  idempotency_key uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz NULL,
  CONSTRAINT service_requests_session_fk
    FOREIGN KEY (establishment_id, guest_session_id)
    REFERENCES public.guest_sessions(establishment_id, id)
    ON DELETE RESTRICT,
  CONSTRAINT service_requests_guest_client_fk
    FOREIGN KEY (
      establishment_id,
      guest_session_id,
      guest_session_client_id
    )
    REFERENCES public.guest_session_clients(
      establishment_id,
      guest_session_id,
      id
    )
    ON DELETE RESTRICT,
  CONSTRAINT service_requests_assignee_fk
    FOREIGN KEY (establishment_id, assigned_to_user_id)
    REFERENCES public.memberships(establishment_id, user_id)
    ON DELETE RESTRICT,
  CONSTRAINT service_requests_establishment_session_id_unique
    UNIQUE (establishment_id, guest_session_id, id),
  CONSTRAINT service_requests_idempotency_unique
    UNIQUE (establishment_id, guest_session_client_id, idempotency_key),
  CONSTRAINT service_requests_resolved_at_check CHECK (
    (status = 'resolved') = (resolved_at IS NOT NULL)
  )
);

CREATE UNIQUE INDEX service_requests_one_active_type_per_session
  ON public.service_requests (establishment_id, guest_session_id, type)
  WHERE status IN ('open', 'in_progress');
CREATE INDEX service_requests_tenant_status_created_idx
  ON public.service_requests (establishment_id, status, created_at DESC);
CREATE INDEX service_requests_session_type_created_idx
  ON public.service_requests (
    establishment_id,
    guest_session_id,
    type,
    created_at DESC
  );
CREATE INDEX service_requests_assignee_idx
  ON public.service_requests (establishment_id, assigned_to_user_id)
  WHERE assigned_to_user_id IS NOT NULL;

CREATE TABLE public.service_request_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  establishment_id uuid NOT NULL,
  guest_session_id uuid NOT NULL,
  service_request_id uuid NOT NULL,
  actor_type text NOT NULL CHECK (actor_type IN ('staff', 'guest', 'system')),
  actor_user_id uuid NULL,
  actor_guest_session_client_id uuid NULL,
  event_type text NOT NULL
    CHECK (event_type IN (
      'request_created',
      'assigned',
      'status_changed',
      'cancelled'
    )),
  old_status text NULL
    CHECK (old_status IS NULL OR old_status IN (
      'open', 'in_progress', 'resolved', 'cancelled'
    )),
  new_status text NULL
    CHECK (new_status IS NULL OR new_status IN (
      'open', 'in_progress', 'resolved', 'cancelled'
    )),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT service_request_events_request_fk
    FOREIGN KEY (establishment_id, guest_session_id, service_request_id)
    REFERENCES public.service_requests(
      establishment_id,
      guest_session_id,
      id
    )
    ON DELETE RESTRICT,
  CONSTRAINT service_request_events_staff_actor_fk
    FOREIGN KEY (establishment_id, actor_user_id)
    REFERENCES public.memberships(establishment_id, user_id)
    ON DELETE RESTRICT,
  CONSTRAINT service_request_events_guest_actor_fk
    FOREIGN KEY (
      establishment_id,
      guest_session_id,
      actor_guest_session_client_id
    )
    REFERENCES public.guest_session_clients(
      establishment_id,
      guest_session_id,
      id
    )
    ON DELETE RESTRICT,
  CONSTRAINT service_request_events_actor_fields_check CHECK (
    (
      actor_type = 'staff'
      AND actor_user_id IS NOT NULL
      AND actor_guest_session_client_id IS NULL
    )
    OR (
      actor_type = 'guest'
      AND actor_user_id IS NULL
      AND actor_guest_session_client_id IS NOT NULL
    )
    OR (
      actor_type = 'system'
      AND actor_user_id IS NULL
      AND actor_guest_session_client_id IS NULL
    )
  )
);

CREATE INDEX service_request_events_request_created_idx
  ON public.service_request_events (service_request_id, created_at, id);
CREATE INDEX service_request_events_tenant_created_idx
  ON public.service_request_events (establishment_id, created_at DESC);

CREATE TABLE public.reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  establishment_id uuid NOT NULL,
  guest_session_id uuid NOT NULL,
  guest_session_client_id uuid NOT NULL,
  rating smallint NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment text NULL
    CHECK (comment IS NULL OR length(comment) <= 2000),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'published', 'hidden')),
  moderated_by_user_id uuid NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  moderated_at timestamptz NULL,
  CONSTRAINT reviews_session_fk
    FOREIGN KEY (establishment_id, guest_session_id)
    REFERENCES public.guest_sessions(establishment_id, id)
    ON DELETE RESTRICT,
  CONSTRAINT reviews_guest_client_fk
    FOREIGN KEY (
      establishment_id,
      guest_session_id,
      guest_session_client_id
    )
    REFERENCES public.guest_session_clients(
      establishment_id,
      guest_session_id,
      id
    )
    ON DELETE RESTRICT,
  CONSTRAINT reviews_moderator_fk
    FOREIGN KEY (establishment_id, moderated_by_user_id)
    REFERENCES public.memberships(establishment_id, user_id)
    ON DELETE RESTRICT,
  CONSTRAINT reviews_one_per_session_unique UNIQUE (guest_session_id),
  CONSTRAINT reviews_moderation_fields_check CHECK (
    (
      status = 'pending'
      AND moderated_by_user_id IS NULL
      AND moderated_at IS NULL
    )
    OR (
      status IN ('published', 'hidden')
      AND moderated_by_user_id IS NOT NULL
      AND moderated_at IS NOT NULL
    )
  )
);

CREATE INDEX reviews_tenant_status_created_idx
  ON public.reviews (establishment_id, status, created_at DESC);

CREATE TABLE private.qr_redemption_attempts (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  credential_id uuid NULL
    REFERENCES private.table_qr_credentials(id) ON DELETE RESTRICT,
  token_fingerprint bytea NOT NULL
    CHECK (octet_length(token_fingerprint) = 32),
  auth_user_id uuid NULL
    REFERENCES auth.users(id) ON DELETE SET NULL,
  attempted_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE INDEX qr_redemption_attempts_credential_time_idx
  ON private.qr_redemption_attempts (credential_id, attempted_at)
  WHERE credential_id IS NOT NULL;
CREATE INDEX qr_redemption_attempts_user_time_idx
  ON private.qr_redemption_attempts (auth_user_id, attempted_at)
  WHERE auth_user_id IS NOT NULL;
CREATE INDEX qr_redemption_attempts_fingerprint_time_idx
  ON private.qr_redemption_attempts (token_fingerprint, attempted_at);

CREATE FUNCTION private.cleanup_qr_redemption_attempts()
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
DECLARE
  deleted_count bigint;
BEGIN
  DELETE FROM private.qr_redemption_attempts
  WHERE attempted_at < pg_catalog.clock_timestamp() - interval '24 hours';

  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$;

CREATE TRIGGER profiles_set_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER establishments_set_updated_at
  BEFORE UPDATE ON public.establishments
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER memberships_set_updated_at
  BEFORE UPDATE ON public.memberships
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER staff_invitations_set_updated_at
  BEFORE UPDATE ON public.staff_invitations
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER dining_tables_set_updated_at
  BEFORE UPDATE ON public.dining_tables
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();
CREATE TRIGGER service_requests_set_updated_at
  BEFORE UPDATE ON public.service_requests
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();

REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA private
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA private
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA private
  FROM PUBLIC, anon, authenticated, service_role;