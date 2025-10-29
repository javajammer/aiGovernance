
import React from 'react';

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

export default FormField;
