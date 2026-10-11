-- =========================================================================
-- ESQUEMA DE BASE DE DATOS GMAO / CMMS INDUSTRIAL - SISTEMAMAXI
-- Copiar y pegar este script en: Supabase Dashboard -> SQL Editor -> Run
-- (Este script es 100% seguro de ejecutar múltiples veces sin errores)
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
    unit TEXT NOT NULL DEFAULT 'un',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

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
    scheduled_date TIMESTAMP WITH TIME ZONE NOT NULL,
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    elapsed_minutes INTEGER DEFAULT 0,
    pause_reason TEXT,
    safety_protocols JSONB DEFAULT '[]'::jsonb,
    root_cause TEXT,
    technician_notes TEXT,
    supervisor_signature TEXT,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. Tabla de Checklists y Mediciones de la OT
CREATE TABLE IF NOT EXISTS public.checklist_items (
    id TEXT PRIMARY KEY,
    work_order_id TEXT NOT NULL REFERENCES public.work_orders(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    type TEXT NOT NULL DEFAULT 'booleanCheck',
    is_completed BOOLEAN DEFAULT false,
    numeric_value DOUBLE PRECISION,
    unit TEXT,
    min_acceptable DOUBLE PRECISION,
    max_acceptable DOUBLE PRECISION,
    notes TEXT,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 5. Tabla de Evidencias Fotográficas vinculadas a la OT
CREATE TABLE IF NOT EXISTS public.evidence_photos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    work_order_id TEXT NOT NULL REFERENCES public.work_orders(id) ON DELETE CASCADE,
    photo_url TEXT NOT NULL,
    caption TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
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
