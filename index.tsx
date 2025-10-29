
import React, { useState, useCallback } from 'react';
import ReactDOM from 'react-dom/client';

// Komponen SuccessMessage (sebelumnya di file terpisah)
const SuccessMessage: React.FC = () => {
  return (
    <div className="text-center py-10 px-4">
      <div className="mx-auto flex items-center justify-center h-16 w-16 rounded-full bg-green-100 dark:bg-green-900">
        <svg
          className="h-8 w-8 text-green-600 dark:text-green-400"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
          xmlns="http://www.w3.org/2000/svg"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth="2"
            d="M5 13l4 4L19 7"
          ></path>
        </svg>
      </div>
      <h2 className="mt-4 text-2xl font-bold text-slate-800 dark:text-white">
        Terima Kasih!
      </h2>
      <p className="mt-2 text-slate-500 dark:text-slate-400">
        Data Anda telah berhasil dikirim. Kami akan meninjaunya segera.
      </p>
    </div>
  );
};


// Komponen FormField (sebelumnya di file terpisah)
interface FormFieldProps {
  label: string;
  id: string;
  type: 'text' | 'url' | 'textarea';
  value: string;
  onChange: (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => void;
  placeholder?: string;
  required?: boolean;
  error?: string;
}

const FormField: React.FC<FormFieldProps> = ({
  label,
  id,
  type,
  value,
  onChange,
  placeholder,
  required = false,
  error,
}) => {
  const commonProps = {
    id,
    name: id,
    value,
    onChange,
    placeholder,
    required,
    className: `w-full px-4 py-2 mt-2 bg-slate-50 dark:bg-slate-700 border rounded-lg focus:outline-none focus:ring-2 dark:text-white transition-colors duration-300 ${
      error 
      ? 'border-red-500 focus:ring-red-500' 
      : 'border-slate-300 dark:border-slate-600 focus:border-indigo-500 focus:ring-indigo-500'
    }`,
  };

  return (
    <div>
      <label htmlFor={id} className="text-sm font-medium text-slate-700 dark:text-slate-300">
        {label}
        {required && <span className="text-red-500 ml-1">*</span>}
      </label>
      {type === 'textarea' ? (
        <textarea {...commonProps} rows={4} />
      ) : (
        <input type={type} {...commonProps} />
      )}
      {error && <p className="mt-1 text-xs text-red-500">{error}</p>}
    </div>
  );
};


// Komponen App (sebelumnya di file terpisah)
interface FormData {
  serviceUrl: string;
  tosUrl: string;
  userPolicyUrl: string;
  aiPolicyUrl: string;
  legalUrl: string;
  department: string;
  purpose: string;
  dataUsed: string;
}

const initialFormData: FormData = {
  serviceUrl: '',
  tosUrl: '',
  userPolicyUrl: '',
  aiPolicyUrl: '',
  legalUrl: '',
  department: '',
  purpose: '',
  dataUsed: '',
};

// !!! PENTING: Ganti dengan URL Web App dari Google Apps Script Anda !!!
const GOOGLE_SCRIPT_URL = 'https://script.google.com/macros/s/AKfycbyXEc6PSiWvrsruoAQALfz_8YE5k7bNcRUrDgYXNWLFV4zDLzQ2XDnns1rudgQCUxiA/exec';

const App: React.FC = () => {
  const [formData, setFormData] = useState<FormData>(initialFormData);
  const [status, setStatus] = useState<'idle' | 'submitting' | 'success' | 'error'>('idle');
  const [errors, setErrors] = useState<Partial<Record<keyof FormData, string>>>({});
  const [submissionError, setSubmissionError] = useState<string | null>(null);

  const handleChange = useCallback((e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    const { id, value } = e.target;
    setFormData(prev => ({ ...prev, [id]: value }));
    if (errors[id as keyof FormData]) {
        setErrors(prev => ({...prev, [id]: undefined}));
    }
  }, [errors]);

  const validateForm = () => {
    if (GOOGLE_SCRIPT_URL === 'YOUR_GOOGLE_APPS_SCRIPT_URL_HERE') {
        setSubmissionError('Harap konfigurasi GOOGLE_SCRIPT_URL di dalam kode index.tsx terlebih dahulu.');
        return false;
    }
    const newErrors: Partial<Record<keyof FormData, string>> = {};
    const urlRegex = /^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$/;

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

  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    if (!validateForm()) {
        return;
    }

    setStatus('submitting');
    setSubmissionError(null);
    
    try {
      // NOTE: Google Apps Script with `doPost` doesn't support preflight (OPTIONS) requests
      // which are sent with `Content-Type: application/json`. A common workaround is
      // to send as text/plain and parse on the server, or to use a simpler POST
      // that avoids preflight, but here we will try direct fetch.
      // Because we use `mode: 'no-cors'`, we cannot see the response,
      // so we have to optimistically assume it succeeded.
      await fetch(GOOGLE_SCRIPT_URL, {
        method: 'POST',
        mode: 'no-cors', 
        headers: {
          // 'Content-Type': 'application/json', // This header can trigger a CORS preflight request
        },
        body: JSON.stringify(formData), // The Apps Script will parse this string
        redirect: 'follow',
      });

      setStatus('success');
      setFormData(initialFormData);
      setTimeout(() => setStatus('idle'), 5000);

    } catch (error) {
      console.error('Error submitting form:', error);
      setStatus('error');
      setSubmissionError('Terjadi kesalahan saat mengirim data. Silakan periksa konsol untuk detailnya.');
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center p-4 bg-slate-50 dark:bg-slate-900 transition-colors duration-300">
      <div className="w-full max-w-2xl mx-auto">
        <div className="bg-white dark:bg-slate-800 shadow-2xl rounded-2xl p-6 md:p-10 border border-slate-200 dark:border-slate-700">
          <div className="text-center mb-8">
            <h1 className="text-3xl font-bold text-slate-800 dark:text-white">Formulir Pengumpulan Data</h1>
            <p className="text-slate-500 dark:text-slate-400 mt-2">Silakan isi detail di bawah ini dengan lengkap.</p>
          </div>
          
          {status === 'success' ? (
            <SuccessMessage />
          ) : (
            <form onSubmit={handleSubmit} noValidate>
              <div className="space-y-6">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <FormField label="URL Layanan" id="serviceUrl" type="url" value={formData.serviceUrl} onChange={handleChange} placeholder="https://example.com" error={errors.serviceUrl} />
                  <FormField label="URL Term of Service" id="tosUrl" type="url" value={formData.tosUrl} onChange={handleChange} placeholder="https://example.com/tos" error={errors.tosUrl} />
                  <FormField label="URL User Policy" id="userPolicyUrl" type="url" value={formData.userPolicyUrl} onChange={handleChange} placeholder="https://example.com/policy" error={errors.userPolicyUrl} />
                  <FormField label="URL AI Policy" id="aiPolicyUrl" type="url" value={formData.aiPolicyUrl} onChange={handleChange} placeholder="https://example.com/ai-policy" error={errors.aiPolicyUrl} />
                </div>
                
                <FormField label="URL Legal" id="legalUrl" type="url" value={formData.legalUrl} onChange={handleChange} placeholder="https://example.com/legal" error={errors.legalUrl} />
                <FormField label="Departemen Pengguna" id="department" type="text" value={formData.department} onChange={handleChange} placeholder="cth: Pemasaran, Teknik" required error={errors.department} />
                <FormField label="Tujuan Penggunaan" id="purpose" type="textarea" value={formData.purpose} onChange={handleChange} placeholder="Jelaskan tujuan penggunaan layanan ini..." required error={errors.purpose} />
                <FormField label="Data yang Digunakan" id="dataUsed" type="textarea" value={formData.dataUsed} onChange={handleChange} placeholder="Sebutkan jenis data yang akan digunakan..." required error={errors.dataUsed} />

                {submissionError && (
                  <div className="text-center p-2 bg-red-100 dark:bg-red-900 border border-red-400 text-red-700 dark:text-red-300 rounded-lg text-sm">
                    {submissionError}
                  </div>
                )}

                <div className="pt-4">
                  <button
                    type="submit"
                    disabled={status === 'submitting'}
                    className="w-full bg-indigo-600 text-white font-bold py-3 px-4 rounded-lg hover:bg-indigo-700 focus:outline-none focus:ring-4 focus:ring-indigo-500 focus:ring-opacity-50 transition-all duration-300 disabled:bg-indigo-400 disabled:cursor-not-allowed flex items-center justify-center"
                  >
                    {status === 'submitting' ? (
                      <>
                        <svg className="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                          <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                          <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                        </svg>
                        Mengirim...
                      </>
                    ) : (
                      'Kirim Data'
                    )}
                  </button>
                </div>
              </div>
            </form>
          )}
        </div>
        <footer className="text-center mt-6 text-sm text-slate-500 dark:text-slate-400">
          <p>&copy; {new Date().getFullYear()} Perusahaan Anda. Hak Cipta Dilindungi.</p>
        </footer>
      </div>
    </div>
  );
};


// Logika Render Aplikasi
const rootElement = document.getElementById('root');
if (!rootElement) {
  throw new Error("Could not find root element to mount to");
}

const root = ReactDOM.createRoot(rootElement);
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
