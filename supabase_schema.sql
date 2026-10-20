-- =========================================================================
-- ESQUEMA DE BASE DE DATOS GMAO / CMMS INDUSTRIAL - CAUQUÉN CMMS (SISTEMAMAXI)
-- Copiar y pegar este script en: Supabase Dashboard -> SQL Editor -> Run
-- (Este script es 100% idempotente y seguro de ejecutar múltiples veces)
-- =========================================================================

-- 1. Tabla de Activos y Equipos de Planta
CREATE TABLE IF NOT EXISTS public.assets (
    id TEXT PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    location TEXT NOT NULL,
    criticality TEXT NOT NULL DEFAULT 'MEDIA',
    status TEXT NOT NULL DEFAULT 'OPERATIVO',
    last_maintenance TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Tabla de Repuestos e Insumos
CREATE TABLE IF NOT EXISTS public.spare_parts (
    id TEXT PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    description TEXT NOT NULL,
    location_warehouse TEXT NOT NULL,
    stock_available INTEGER NOT NULL DEFAULT 0,
    min_stock_alert INTEGER NOT NULL DEFAULT 5,
    unit TEXT NOT NULL DEFAULT 'un',
    unit_cost DOUBLE PRECISION NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.spare_parts ADD COLUMN IF NOT EXISTS min_stock_alert INTEGER NOT NULL DEFAULT 5;
ALTER TABLE public.spare_parts ADD COLUMN IF NOT EXISTS unit_cost DOUBLE PRECISION NOT NULL DEFAULT 0;

-- 3. Tabla Principal de Órdenes de Trabajo (OT)
CREATE TABLE IF NOT EXISTS public.work_orders (
    id TEXT PRIMARY KEY,
    order_number TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'correctivo',
    priority TEXT NOT NULL DEFAULT 'normal',
    status TEXT NOT NULL DEFAULT 'pendiente',
    asset_id TEXT REFERENCES public.assets(id) ON DELETE SET NULL,
    technician_name TEXT NOT NULL,
    technician_badge TEXT NOT NULL,
    assigned_crew TEXT,
    scheduled_date TIMESTAMP WITH TIME ZONE NOT NULL,
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    elapsed_minutes INTEGER DEFAULT 0,
    pause_reason TEXT,
    safety_protocols JSONB DEFAULT '[]'::jsonb,
    stages JSONB DEFAULT '[]'::jsonb,
    spare_parts_json JSONB DEFAULT '[]'::jsonb,
    evidence_photos_json JSONB DEFAULT '[]'::jsonb,
    root_cause TEXT,
    technician_notes TEXT,
    supervisor_signature TEXT,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.work_orders ADD COLUMN IF NOT EXISTS assigned_crew TEXT;
ALTER TABLE public.work_orders ADD COLUMN IF NOT EXISTS stages JSONB DEFAULT '[]'::jsonb;
ALTER TABLE public.work_orders ADD COLUMN IF NOT EXISTS spare_parts_json JSONB DEFAULT '[]'::jsonb;
ALTER TABLE public.work_orders ADD COLUMN IF NOT EXISTS evidence_photos_json JSONB DEFAULT '[]'::jsonb;

-- 4. Tabla de Checklists, Etapas y Mediciones de la OT (Soporte MaintainX Completo)
CREATE TABLE IF NOT EXISTS public.checklist_items (
    id TEXT PRIMARY KEY,
    work_order_id TEXT NOT NULL REFERENCES public.work_orders(id) ON DELETE CASCADE,
    stage_id TEXT DEFAULT 'stg-1',
    stage_name TEXT DEFAULT 'Etapa 1: Procedimientos Iniciales',
    title TEXT NOT NULL,
    description TEXT,
    type TEXT NOT NULL DEFAULT 'booleanCheck',
    is_completed BOOLEAN DEFAULT false,
    is_required BOOLEAN DEFAULT true,
    numeric_value DOUBLE PRECISION,
    unit TEXT,
    min_acceptable DOUBLE PRECISION,
    max_acceptable DOUBLE PRECISION,
    photo_url TEXT,
    photo_urls JSONB DEFAULT '[]'::jsonb,
    min_photos INTEGER DEFAULT 1,
    max_photos INTEGER DEFAULT 5,
    photo_before_url TEXT,
    photo_after_url TEXT,
    options JSONB DEFAULT '[]'::jsonb,
    selected_option TEXT,
    selected_options JSONB DEFAULT '[]'::jsonb,
    text_value TEXT,
    notes TEXT,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.checklist_items ADD COLUMN IF NOT EXISTS stage_id TEXT DEFAULT 'stg-1';
ALTER TABLE public.checklist_items ADD COLUMN IF NOT EXISTS stage_name TEXT DEFAULT 'Etapa 1: Procedimientos Iniciales';
ALTER TABLE public.checklist_items ADD COLUMN IF NOT EXISTS is_required BOOLEAN DEFAULT true;
ALTER TABLE public.checklist_items ADD COLUMN IF NOT EXISTS photo_url TEXT;
ALTER TABLE public.checklist_items ADD COLUMN IF NOT EXISTS photo_urls JSONB DEFAULT '[]'::jsonb;
ALTER TABLE public.checklist_items ADD COLUMN IF NOT EXISTS min_photos INTEGER DEFAULT 1;
ALTER TABLE public.checklist_items ADD COLUMN IF NOT EXISTS max_photos INTEGER DEFAULT 5;
ALTER TABLE public.checklist_items ADD COLUMN IF NOT EXISTS photo_before_url TEXT;
ALTER TABLE public.checklist_items ADD COLUMN IF NOT EXISTS photo_after_url TEXT;
ALTER TABLE public.checklist_items ADD COLUMN IF NOT EXISTS options JSONB DEFAULT '[]'::jsonb;
ALTER TABLE public.checklist_items ADD COLUMN IF NOT EXISTS selected_option TEXT;
ALTER TABLE public.checklist_items ADD COLUMN IF NOT EXISTS selected_options JSONB DEFAULT '[]'::jsonb;
ALTER TABLE public.checklist_items ADD COLUMN IF NOT EXISTS text_value TEXT;

-- 5. Tabla de Evidencias Fotográficas vinculadas a la OT
CREATE TABLE IF NOT EXISTS public.evidence_photos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    work_order_id TEXT NOT NULL REFERENCES public.work_orders(id) ON DELETE CASCADE,
    photo_url TEXT NOT NULL,
    caption TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 6. Tabla de Protocolos y Plantillas Técnicas Maestras (MaintainX)
CREATE TABLE IF NOT EXISTS public.task_templates (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    type TEXT NOT NULL DEFAULT 'preventivo',
    default_priority TEXT NOT NULL DEFAULT 'normal',
    estimated_minutes INTEGER NOT NULL DEFAULT 45,
    stages JSONB DEFAULT '[]'::jsonb,
    steps JSONB DEFAULT '[]'::jsonb,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 7. Tabla de Cuadrillas de Planta
CREATE TABLE IF NOT EXISTS public.crews (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    shift TEXT NOT NULL DEFAULT 'Turno Mañana',
    specialty TEXT NOT NULL DEFAULT 'Mantenimiento General',
    leader_name TEXT NOT NULL DEFAULT 'Sin asignar',
    leader_badge TEXT NOT NULL DEFAULT 'SUP-0000',
    member_names JSONB DEFAULT '[]'::jsonb,
    notes TEXT DEFAULT '',
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 8. Tabla de Personal / Usuarios de Planta
CREATE TABLE IF NOT EXISTS public.plant_users (
    id TEXT PRIMARY KEY,
    email TEXT NOT NULL,
    name TEXT NOT NULL,
    badge TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'technician',
    shift TEXT NOT NULL DEFAULT 'Turno Mañana',
    specialty TEXT NOT NULL DEFAULT 'Mantenimiento General',
    phone TEXT DEFAULT '',
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- =========================================================================
-- Índices para rendimiento óptimo
-- =========================================================================
CREATE INDEX IF NOT EXISTS idx_work_orders_status ON public.work_orders(status);
CREATE INDEX IF NOT EXISTS idx_work_orders_technician ON public.work_orders(technician_badge);
CREATE INDEX IF NOT EXISTS idx_checklist_work_order ON public.checklist_items(work_order_id);

-- =========================================================================
-- Políticas de Seguridad RLS (Lectura y Escritura con DROP IF EXISTS)
-- =========================================================================
ALTER TABLE public.assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.spare_parts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.work_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checklist_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.evidence_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.task_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.plant_users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Permitir todo a usuarios autorizados" ON public.assets;
CREATE POLICY "Permitir todo a usuarios autorizados" ON public.assets FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Permitir todo a usuarios autorizados" ON public.spare_parts;
CREATE POLICY "Permitir todo a usuarios autorizados" ON public.spare_parts FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Permitir todo a usuarios autorizados" ON public.work_orders;
CREATE POLICY "Permitir todo a usuarios autorizados" ON public.work_orders FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Permitir todo a usuarios autorizados" ON public.checklist_items;
CREATE POLICY "Permitir todo a usuarios autorizados" ON public.checklist_items FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Permitir todo a usuarios autorizados" ON public.evidence_photos;
CREATE POLICY "Permitir todo a usuarios autorizados" ON public.evidence_photos FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Permitir todo a usuarios autorizados" ON public.task_templates;
CREATE POLICY "Permitir todo a usuarios autorizados" ON public.task_templates FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Permitir todo a usuarios autorizados" ON public.crews;
CREATE POLICY "Permitir todo a usuarios autorizados" ON public.crews FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Permitir todo a usuarios autorizados" ON public.plant_users;
CREATE POLICY "Permitir todo a usuarios autorizados" ON public.plant_users FOR ALL USING (true) WITH CHECK (true);

-- =========================================================================
-- Almacenamiento (Storage Buckets para fotos de cámara y firmas)
-- =========================================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('evidences', 'evidences', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Permitir subida y lectura de fotos públicas" ON storage.objects;
CREATE POLICY "Permitir subida y lectura de fotos públicas"
ON storage.objects FOR ALL
USING (bucket_id = 'evidences')
WITH CHECK (bucket_id = 'evidences');
