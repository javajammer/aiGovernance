
import React from 'react';

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

export default SuccessMessage;
