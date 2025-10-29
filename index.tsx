import React, { useState, useCallback } from 'react';
import ReactDOM from 'react-dom/client';

/* ... SuccessMessage & FormField tetap sama ... */

// --- snip ---

// Lebih toleran untuk URL (biar tidak false negative)
const urlRegex = /^https?:\/\/[^\s/$.?#].[^\s]*$/i;

const validateForm = () => {
  if (GOOGLE_SCRIPT_URL === 'YOUR_GOOGLE_APPS_SCRIPT_URL_HERE') {
    setSubmissionError('Harap konfigurasi GOOGLE_SCRIPT_URL di dalam kode index.tsx terlebih dahulu.');
    return false;
  }
  const newErrors: Partial<Record<keyof FormData, string>> = {};

  if (formData.serviceUrl && !urlRegex.test(formData.serviceUrl)) newErrors.serviceUrl = "URL layanan tidak valid.";
  if (formData.tosUrl && !urlRegex.test(formData.tosUrl)) newErrors.tosUrl = "URL Term of Service tidak valid.";
  if (formData.userPolicyUrl && !urlRegex.test(formData.userPolicyUrl)) newErrors.userPolicyUrl = "URL User Policy tidak valid.";
  if (formData.aiPolicyUrl && !urlRegex.test(formData.aiPolicyUrl)) newErrors.aiPolicyUrl = "URL AI Policy tidak valid.";
  if (formData.legalUrl && !urlRegex.test(formData.legalUrl)) newErrors.legalUrl = "URL Legal tidak valid.";
  if (!formData.department) newErrors.department = "Departemen pengguna wajib diisi.";
  if (!formData.purpose) newErrors.purpose = "Tujuan penggunaan wajib diisi.";
  if (!formData.dataUsed) newErrors.dataUsed = "Data yang digunakan wajib diisi.";

  setErrors(newErrors);
  return Object.keys(newErrors).length === 0;
};
