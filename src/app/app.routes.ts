import { Routes } from '@angular/router';
import { HomeComponent } from './features/home/home.component';
import { JobRequestComponent } from './features/job-request/job-request/job-request.component';
import { ArtisanListComponent } from './features/pro-search/artisan-list/artisan-list.component';
import { DashboardComponent } from './features/dashboard/dashboard.component';
import { UserProfileComponent } from './features/dashboard/user-profile/user-profile.component';
import { WorkerProfileComponent } from './features/dashboard/worker-profile/worker-profile.component';
import { RoleSelectionComponent } from './features/auth/role-selection/role-selection.component';
import { LoginComponent } from './features/auth/login/login.component';
import { RegisterComponent } from './features/auth/register/register.component';
import { authGuard } from './core/guards/auth.guard';

export const routes: Routes = [
  // Page d'accueil publique (Landing Page)
  { 
    path: '', 
    component: HomeComponent,
    title: 'Snay3ia - Accueil'
  },
  
  // Authentification
  {
    path: 'login',
    component: LoginComponent,
    title: 'Connexion'
  },
  {
    path: 'register',
    component: RegisterComponent,
    title: 'Inscription'
  },
  
  // Sélection de rôle (après inscription ou première connexion si non défini)
  {
    path: 'role-select',
    component: RoleSelectionComponent,
    title: 'Snay3ia - Qui êtes-vous ?'
  },
  
  // Routes protégées (Tableau de bord connecté)
  {
    path: 'dashboard',
    component: DashboardComponent,
    canActivate: [authGuard],
    children: [
      { path: 'client', component: UserProfileComponent, title: 'Mon Espace Client' },
      { path: 'worker', component: WorkerProfileComponent, title: 'Mon Espace Pro' },
      // Redirection intelligente
      { path: '', redirectTo: 'client', pathMatch: 'full' }
    ]
  },

  // Fonctionnalités spécifiques
  { 
    path: 'job-request', 
    component: JobRequestComponent,
    title: 'Nouvelle Demande'
  },
  
  { 
    path: 'pro-search', 
    component: ArtisanListComponent,
    title: 'Trouver un Pro'
  },

  // Fallback
  { 
    path: '**', 
    redirectTo: '' 
  }
];
