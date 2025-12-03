import { Component, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Sannay3iService } from '../../../core/services/sannay3i.service';

@Component({
  selector: 'app-job-request',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './job-request.component.html',
  styleUrl: './job-request.component.scss',
})
export class JobRequestComponent {
  private sannay3iService = inject(Sannay3iService);
  private cdr = inject(ChangeDetectorRef);

  jobDescription: string = '';
  jobFiles: File[] = []; 
  
  isUploading = false;
  isSuccess = false;
  uploadMessage = '';

  // Limite de taille en octets (10 Mo)
  readonly MAX_SIZE = 10 * 1024 * 1024; 

  onFileSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    if (input.files && input.files.length > 0) {
      const selectedFiles = Array.from(input.files);
      
      // Validation de la taille
      const oversizedFiles = selectedFiles.filter(f => f.size > this.MAX_SIZE);
      
      if (oversizedFiles.length > 0) {
        alert(`Certains fichiers sont trop volumineux (Max 10Mo) : \n${oversizedFiles.map(f => f.name).join(', ')}`);
        // On ne garde que les fichiers valides
        this.jobFiles = selectedFiles.filter(f => f.size <= this.MAX_SIZE);
      } else {
        this.jobFiles = selectedFiles;
      }

      if (this.jobFiles.length > 0) {
        this.uploadMessage = `${this.jobFiles.length} fichier(s) prêt(s)`;
      } else {
        this.uploadMessage = '';
        input.value = ''; // Reset input
      }
    }
  }

  async submitJobRequest(): Promise<void> {
    if (!this.jobDescription || this.jobFiles.length === 0) {
      this.uploadMessage = 'Description et au moins une image requises.';
      return;
    }

    this.isUploading = true;
    this.uploadMessage = `Envoi de ${this.jobFiles.length} fichiers en cours...`;
    this.cdr.detectChanges(); // Force UI update
    
    try {
      await this.sannay3iService.createJob(this.jobDescription, this.jobFiles);
      
      this.isSuccess = true; 
      this.isUploading = false; 
      this.jobDescription = '';
      this.jobFiles = [];
      this.uploadMessage = '';
      this.cdr.detectChanges();

    } catch (error: any) {
      this.isUploading = false;
      this.isSuccess = false;
      // Affichage propre du message d'erreur
      this.uploadMessage = error.message || 'Une erreur est survenue lors de l\'envoi.';
      this.cdr.detectChanges();
    }
  }

  resetView(): void {
    this.isSuccess = false;
    this.uploadMessage = '';
    this.cdr.detectChanges();
  }
}
