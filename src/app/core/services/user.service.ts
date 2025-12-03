import { Injectable } from '@angular/core';
import { of, Observable } from 'rxjs';
import { delay } from 'rxjs/operators';

export interface WorkerProfile {
  uid: string;
  displayName: string;
  specialty: string;
  rating: number;
  completedJobs: number;
  reviews: { author: string; comment: string; rating: number }[];
}

@Injectable({
  providedIn: 'root'
})
export class UserService {
  // Mock Data
  getWorkerProfile(workerId: string): Observable<WorkerProfile> {
    const mockProfiles: WorkerProfile[] = [
      {
        uid: workerId,
        displayName: 'Ahmed B.',
        specialty: 'Électricien Expert',
        rating: 4.8,
        completedJobs: 142,
        reviews: [
          { author: 'Sami K.', comment: 'Très professionnel et rapide.', rating: 5 },
          { author: 'Leila M.', comment: 'Bon travail, prix correct.', rating: 4 },
          { author: 'Karim T.', comment: 'A résolu ma panne en 10min.', rating: 5 }
        ]
      }
    ];
    return of(mockProfiles[0]).pipe(delay(500));
  }
}
