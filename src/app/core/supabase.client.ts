import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { environment } from '../../environments/environment';

// Initialise et exporte le client Supabase
const supabaseConfig = environment.supabaseConfig;

/**
 * Client Supabase initialisé.
 * Utilisé principalement pour le stockage (Storage) et les appels directs à Supabase.
 */
export const supabase: SupabaseClient = createClient(
  supabaseConfig.url,
  supabaseConfig.key
);

/**
 * Nom du bucket Supabase pour les dossiers de panne ('breakdowns').
 */
export const STORAGE_BUCKET_BREAKDOWNS = 'breakdowns';

/**
 * L'ancien bucket 'litaliano' (pour référence).
 */
export const STORAGE_BUCKET_LITALIANO = supabaseConfig.storageBucket;
