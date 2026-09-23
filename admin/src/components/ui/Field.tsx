import {
  createContext,
  useContext,
  useId,
  type AriaAttributes,
  type ReactNode,
} from 'react';

import { Icon } from '../Icon';
import { cx } from './logic';

interface FieldContext {
  id: string;
  describedBy: string | undefined;
  invalid: boolean;
  required: boolean;
}

const Ctx = createContext<FieldContext | null>(null);

/**
 * Maydon ichidagi kiritish elementi uchun: `id`, `aria-describedby`,
 * `aria-invalid` va `required` ni Field'dan oladi. Element o'zi aniq
 * qiymat bersa — o'shanisi ustun.
 */
export function useFieldProps<P extends {
  id?: string;
  'aria-describedby'?: string;
  'aria-invalid'?: AriaAttributes['aria-invalid'];
  required?: boolean;
}>(props: P): P {
  const field = useContext(Ctx);
  if (!field) return props;
  return {
    ...props,
    id: props.id ?? field.id,
    'aria-describedby': props['aria-describedby'] ?? field.describedBy,
    'aria-invalid': props['aria-invalid'] ?? (field.invalid || undefined),
    required: props.required ?? (field.required || undefined),
  };
}

/**
 * Forma maydoni: yorliq + kiritish elementi + maslahat/xato.
 *
 *   <Field label="Biznes nomi" error={errors.name}>
 *     <Input value={name} onChange={…} />
 *   </Field>
 *
 * Yorliq DOIM ko'rinadi — placeholder yorliq o'rnini bosmaydi: yozish
 * boshlanishi bilan u yo'qoladi va foydalanuvchi nima kiritayotganini
 * unutadi.
 *
 * Majburiy maydon yulduzcha bilan (ekran o'quvchiga `required`
 * atributi aytadi), ixtiyoriysi "(ixtiyoriy)" bilan belgilanadi —
 * formada qaysi biri ko'p bo'lsa, faqat ikkinchisini belgilash kifoya.
 */
export function Field({
  label,
  hint,
  error,
  required = false,
  optional = false,
  id: idProp,
  className,
  children,
}: {
  label: ReactNode;
  hint?: ReactNode;
  /** Xato matni. Bo'sh bo'lsa xato yo'q. */
  error?: ReactNode;
  required?: boolean;
  optional?: boolean;
  id?: string;
  className?: string;
  children: ReactNode;
}) {
  const auto = useId();
  const id = idProp ?? auto;
  const hintId = hint ? `${id}-hint` : undefined;
  const errorId = error ? `${id}-error` : undefined;
  const describedBy = [errorId, hintId].filter(Boolean).join(' ') || undefined;

  return (
    <div className={cx('ui-field', className)}>
      <label htmlFor={id} className="ui-field__label">
        {label}
        {required && (
          <span className="ui-field__req" aria-hidden="true">
            *
          </span>
        )}
        {optional && <span className="ui-field__optional">(ixtiyoriy)</span>}
      </label>

      <Ctx.Provider value={{ id, describedBy, invalid: Boolean(error), required }}>
        {children}
      </Ctx.Provider>

      {hint && (
        <p id={hintId} className="ui-field__hint">
          {hint}
        </p>
      )}
      {error && (
        <p id={errorId} className="ui-field__error">
          <Icon name="error" size={14} />
          <span>{error}</span>
        </p>
      )}
    </div>
  );
}
