CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

BEGIN;

SET LOCAL search_path = extensions, public, private, auth, pg_catalog;

SELECT no_plan();

SELECT has_table('public', 'profiles', 'profiles exists');
SELECT has_table('public', 'establishments', 'establishments exists');
SELECT has_table('public', 'memberships', 'memberships exists');
SELECT has_table('public', 'staff_invitations', 'staff_invitations exists');
SELECT has_table('public', 'dining_tables', 'dining_tables exists');
SELECT has_table('private', 'table_qr_credentials', 'QR credentials are private');
SELECT has_table('public', 'guest_sessions', 'guest_sessions exists');
SELECT has_table('public', 'guest_session_clients', 'guest session clients exist');
SELECT has_table('public', 'service_requests', 'service_requests exists');
SELECT has_table('public', 'service_request_events', 'request event history exists');
SELECT has_table('public', 'reviews', 'reviews exists');
SELECT has_table(
  'private',
  'qr_redemption_attempts',
  'QR redemption attempts are private'
);

SELECT ok(
  NOT has_table_privilege('anon', 'public.profiles', 'SELECT'),
  'anon cannot read public tables before RLS'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.profiles', 'SELECT'),
  'authenticated cannot read public tables before RLS'
);
SELECT ok(
  NOT has_table_privilege('service_role', 'public.profiles', 'SELECT'),
  'service_role has no direct table grants before RLS'
);
SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM information_schema.role_table_grants
    WHERE grantee IN ('anon', 'authenticated', 'service_role')
      AND table_schema IN ('public', 'private')
      AND table_name IN (
        'profiles',
        'establishments',
        'memberships',
        'staff_invitations',
        'dining_tables',
        'table_qr_credentials',
        'guest_sessions',
        'guest_session_clients',
        'service_requests',
        'service_request_events',
        'reviews',
        'qr_redemption_attempts'
      )
  ),
  'API roles have no table privileges before RLS'
);
SELECT ok(
  NOT has_schema_privilege('anon', 'private', 'USAGE')
  AND NOT has_schema_privilege('authenticated', 'private', 'USAGE')
  AND NOT has_schema_privilege('service_role', 'private', 'USAGE'),
  'API roles cannot access the private schema'
);
SELECT ok(
  NOT has_function_privilege(
    'anon',
    'private.cleanup_qr_redemption_attempts()',
    'EXECUTE'
  ),
  'anon cannot execute internal cleanup'
);

INSERT INTO auth.users (id)
VALUES
  ('00000000-0000-0000-0000-000000000001'),
  ('00000000-0000-0000-0000-000000000002'),
  ('00000000-0000-0000-0000-000000000003');

INSERT INTO public.profiles (id, display_name)
VALUES
  ('00000000-0000-0000-0000-000000000001', 'Manager One'),
  ('00000000-0000-0000-0000-000000000002', 'Manager Two');

INSERT INTO public.establishments (id, name, slug, created_by)
VALUES
  (
    '10000000-0000-0000-0000-000000000001',
    'Lanchonete Um',
    'lanchonete-um',
    '00000000-0000-0000-0000-000000000001'
  ),
  (
    '10000000-0000-0000-0000-000000000002',
    'Lanchonete Dois',
    'lanchonete-dois',
    '00000000-0000-0000-0000-000000000002'
  );

INSERT INTO public.memberships (
  establishment_id,
  user_id,
  role
)
VALUES
  (
    '10000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000001',
    'manager'
  ),
  (
    '10000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000002',
    'manager'
  );

INSERT INTO public.dining_tables (id, establishment_id, label)
VALUES
  (
    '20000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    'Mesa 1'
  ),
  (
    '20000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000002',
    'Mesa 1'
  );

INSERT INTO public.guest_sessions (
  id,
  establishment_id,
  dining_table_id
)
VALUES
  (
    '30000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001'
  ),
  (
    '30000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000002',
    '20000000-0000-0000-0000-000000000002'
  );

INSERT INTO public.guest_session_clients (
  id,
  establishment_id,
  guest_session_id,
  auth_user_id
)
VALUES (
  '40000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000003'
);

INSERT INTO public.staff_invitations (
  id,
  establishment_id,
  email,
  role,
  invited_by_user_id
)
VALUES (
  '45000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  'new.employee@example.test',
  'employee',
  '00000000-0000-0000-0000-000000000001'
);

SELECT ok(
  (
    SELECT expires_at > created_at + interval '6 days'
      AND expires_at <= created_at + interval '7 days'
    FROM public.staff_invitations
    WHERE id = '45000000-0000-0000-0000-000000000001'
  ),
  'invitation defaults to a seven-day validity period'
);

SELECT throws_ok(
  $$
    INSERT INTO public.establishments (name, slug, created_by)
    VALUES (
      'Duplicate slug',
      'lanchonete-um',
      '00000000-0000-0000-0000-000000000001'
    )
  $$,
  '23505',
  NULL,
  'duplicate establishment slug is rejected'
);

SELECT throws_ok(
  $$
    INSERT INTO public.dining_tables (establishment_id, label)
    VALUES ('10000000-0000-0000-0000-000000000001', 'mesa 1')
  $$,
  '23505',
  NULL,
  'table labels are unique case-insensitively within a tenant'
);

SELECT throws_ok(
  $$
    INSERT INTO public.guest_sessions (establishment_id, dining_table_id)
    VALUES (
      '10000000-0000-0000-0000-000000000001',
      '20000000-0000-0000-0000-000000000002'
    )
  $$,
  '23503',
  NULL,
  'a session cannot reference a table in another tenant'
);

SELECT throws_ok(
  $$
    INSERT INTO public.guest_sessions (establishment_id, dining_table_id)
    VALUES (
      '10000000-0000-0000-0000-000000000001',
      '20000000-0000-0000-0000-000000000001'
    )
  $$,
  '23505',
  NULL,
  'a table cannot have two active sessions'
);

SELECT throws_ok(
  $$
    INSERT INTO public.guest_sessions (
      establishment_id,
      dining_table_id,
      max_expires_at
    )
    VALUES (
      '10000000-0000-0000-0000-000000000001',
      '20000000-0000-0000-0000-000000000001',
      now() + interval '5 hours'
    )
  $$,
  '23514',
  NULL,
  'session duration cannot exceed four hours'
);

INSERT INTO public.service_requests (
  id,
  establishment_id,
  guest_session_id,
  guest_session_client_id,
  type,
  assigned_to_user_id,
  idempotency_key
)
VALUES (
  '50000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000001',
  'waiter',
  '00000000-0000-0000-0000-000000000001',
  '60000000-0000-0000-0000-000000000001'
);

SELECT throws_ok(
  $$
    INSERT INTO public.service_requests (
      establishment_id,
      guest_session_id,
      guest_session_client_id,
      type,
      idempotency_key
    )
    VALUES (
      '10000000-0000-0000-0000-000000000001',
      '30000000-0000-0000-0000-000000000001',
      '40000000-0000-0000-0000-000000000001',
      'waiter',
      '60000000-0000-0000-0000-000000000002'
    )
  $$,
  '23505',
  NULL,
  'only one active request of each type per session is allowed'
);

SELECT throws_ok(
  $$
    INSERT INTO public.service_requests (
      establishment_id,
      guest_session_id,
      guest_session_client_id,
      type,
      assigned_to_user_id,
      idempotency_key
    )
    VALUES (
      '10000000-0000-0000-0000-000000000001',
      '30000000-0000-0000-0000-000000000001',
      '40000000-0000-0000-0000-000000000001',
      'help',
      '00000000-0000-0000-0000-000000000002',
      '60000000-0000-0000-0000-000000000003'
    )
  $$,
  '23503',
  NULL,
  'a request cannot be assigned to a user from another tenant'
);

INSERT INTO public.reviews (
  id,
  establishment_id,
  guest_session_id,
  guest_session_client_id,
  rating
)
VALUES (
  '70000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000001',
  5
);

SELECT throws_ok(
  $$
    INSERT INTO public.reviews (
      establishment_id,
      guest_session_id,
      guest_session_client_id,
      rating
    )
    VALUES (
      '10000000-0000-0000-0000-000000000001',
      '30000000-0000-0000-0000-000000000001',
      '40000000-0000-0000-0000-000000000001',
      4
    )
  $$,
  '23505',
  NULL,
  'only one review per session is allowed'
);

SELECT throws_ok(
  $$
    INSERT INTO public.reviews (
      establishment_id,
      guest_session_id,
      guest_session_client_id,
      rating
    )
    VALUES (
      '10000000-0000-0000-0000-000000000002',
      '30000000-0000-0000-0000-000000000002',
      '40000000-0000-0000-0000-000000000001',
      4
    )
  $$,
  '23503',
  NULL,
  'a review cannot cross tenant/session boundaries'
);

SELECT throws_ok(
  $$
    INSERT INTO public.reviews (
      establishment_id,
      guest_session_id,
      guest_session_client_id,
      rating
    )
    VALUES (
      '10000000-0000-0000-0000-000000000001',
      '30000000-0000-0000-0000-000000000001',
      '40000000-0000-0000-0000-000000000001',
      6
    )
  $$,
  '23514',
  NULL,
  'ratings outside the one-to-five range are rejected'
);

INSERT INTO private.table_qr_credentials (
  id,
  establishment_id,
  dining_table_id,
  token_hash,
  version,
  created_by_user_id
)
VALUES (
  '80000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  decode(repeat('ab', 32), 'hex'),
  1,
  '00000000-0000-0000-0000-000000000001'
);

SELECT throws_ok(
  $$
    INSERT INTO private.table_qr_credentials (
      establishment_id,
      dining_table_id,
      token_hash,
      version,
      created_by_user_id
    )
    VALUES (
      '10000000-0000-0000-0000-000000000001',
      '20000000-0000-0000-0000-000000000001',
      decode(repeat('cd', 32), 'hex'),
      2,
      '00000000-0000-0000-0000-000000000001'
    )
  $$,
  '23505',
  NULL,
  'a table cannot have two active QR credentials'
);

INSERT INTO private.qr_redemption_attempts (
  credential_id,
  token_fingerprint,
  auth_user_id,
  attempted_at
)
VALUES
  (
    '80000000-0000-0000-0000-000000000001',
    decode(repeat('ab', 32), 'hex'),
    '00000000-0000-0000-0000-000000000003',
    clock_timestamp() - interval '23 hours'
  ),
  (
    '80000000-0000-0000-0000-000000000001',
    decode(repeat('cd', 32), 'hex'),
    '00000000-0000-0000-0000-000000000003',
    clock_timestamp() - interval '25 hours'
  );

SELECT is(
  private.cleanup_qr_redemption_attempts(),
  1::bigint,
  'QR cleanup deletes only attempts older than 24 hours'
);
SELECT is(
  (
    SELECT count(*)
    FROM private.qr_redemption_attempts
    WHERE attempted_at >= clock_timestamp() - interval '24 hours'
  ),
  1::bigint,
  'QR cleanup retains attempts younger than 24 hours'
);

UPDATE public.establishments
SET name = 'Lanchonete Um Atualizada'
WHERE id = '10000000-0000-0000-0000-000000000001';

SELECT ok(
  (
    SELECT updated_at > '2000-01-01 00:00:00+00'::timestamptz
    FROM public.establishments
    WHERE id = '10000000-0000-0000-0000-000000000001'
  ),
  'updated_at is maintained by a database trigger'
);

SELECT * FROM finish();

ROLLBACK;
