import { inject } from '@angular/core';
import { Router, CanActivateFn } from '@angular/router';
import { auth } from '../firebase.config';

export const authGuard: CanActivateFn = (route, state) => {
  const router = inject(Router);
  
  // Note: auth.currentUser est synchrone mais peut être null au chargement initial.
  const user = auth.currentUser;

  if (user) {
    return true;
  } else {
    // Si pas connecté, redirection vers la page de login
    return router.createUrlTree(['/login']);
  }
};
