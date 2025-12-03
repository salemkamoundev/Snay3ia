import { inject } from '@angular/core';
import { Router, CanActivateFn, UrlTree } from '@angular/router';
import { auth } from '../firebase.config';
import { onAuthStateChanged } from 'firebase/auth';

export const authGuard: CanActivateFn = (route, state) => {
  const router = inject(Router);

  // On retourne une Promise pour dire au Router d'attendre la réponse de Firebase
  return new Promise<boolean | UrlTree>((resolve) => {
    // onAuthStateChanged se déclenche dès que Firebase a restauré la session (ou échoué)
    const unsubscribe = onAuthStateChanged(auth, (user) => {
      unsubscribe(); // On se désabonne tout de suite pour ne pas écouter indéfiniment
      
      if (user) {
        resolve(true); // L'utilisateur est connecté (restauré), on laisse passer
      } else {
        // Pas de session, redirection vers login
        resolve(router.createUrlTree(['/login']));
      }
    });
  });
};
