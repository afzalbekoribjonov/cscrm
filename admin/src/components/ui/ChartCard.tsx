import { useState, type ReactNode } from 'react';

import { Button } from './Button';
import { Card } from './Card';
import { EmptyState } from './Feedback';
import { IconButton } from './IconButton';
import { cx } from './logic';
import { Skeleton } from './Skeleton';

export type ChartStatus = 'loading' | 'error' | 'empty' | 'ready';

/**
 * Chart kartasi — sarlavha, holatlar va jadval ko'rinishi.
 *
 * Har bir chartning JADVAL egizagi bor: rangni ajrata olmaydigan,
 * ekran o'quvchidan foydalanadigan yoki aniq raqam kerak bo'lgan
 * foydalanuvchi uchun. Bu ixtiyoriy bezak emas — palitradagi ba'zi
 * ranglar oq fonda 3:1 dan past, va qoida bo'yicha bunday chartda
 * jadval ko'rinishi bo'lishi SHART.
 *
 * Holatlar bir xil balandlikda: yuklanish → ma'lumot o'tishida karta
 * sakramaydi. Qayta yuklashda (`refreshing`) eski chart xira turadi.
 */
export function ChartCard({
  title,
  description,
  actions,
  status,
  error,
  onRetry,
  emptyTitle = 'Bu davr uchun ma\'lumot yo\'q',
  emptyDescription,
  refreshing = false,
  height = 220,
  table,
  children,
}: {
  title: string;
  description?: ReactNode;
  actions?: ReactNode;
  status: ChartStatus;
  error?: string;
  onRetry?: () => void;
  emptyTitle?: string;
  emptyDescription?: string;
  refreshing?: boolean;
  /** Chart maydonining balandligi (o'qlar bilan birga). */
  height?: number;
  table?: { columns: string[]; rows: ReactNode[][] };
  children?: ReactNode;
}) {
  const [asTable, setAsTable] = useState(false);
  const showTable = asTable && status === 'ready' && table;

  return (
    <Card
      title={title}
      description={description}
      actions={
        <>
          {actions}
          {table && status === 'ready' && (
            <IconButton
              icon={asTable ? 'chart' : 'table'}
              label={asTable ? 'Chart ko\'rinishi' : 'Jadval ko\'rinishi'}
              size="sm"
              aria-pressed={asTable}
              onClick={() => setAsTable((v) => !v)}
            />
          )}
        </>
      }
    >
      <div
        className={cx('ui-chart-body', refreshing && 'is-refreshing')}
        style={{ minHeight: height }}
        aria-busy={status === 'loading' || refreshing}
      >
        {status === 'loading' && <Skeleton height={height} radius={10} />}

        {status === 'error' && (
          <EmptyState
            compact
            icon="alert"
            title="Ma'lumotni yuklab bo'lmadi"
            description={error ?? 'Internetni tekshirib, qayta urinib ko\'ring.'}
            action={
              onRetry && (
                <Button variant="outline" size="sm" icon="refresh" onClick={onRetry}>
                  Qayta urinish
                </Button>
              )
            }
          />
        )}

        {status === 'empty' && (
          <EmptyState compact icon="chart" title={emptyTitle} description={emptyDescription} />
        )}

        {status === 'ready' &&
          (showTable ? (
            <div className="ui-chart-table-scroll" style={{ maxHeight: Math.max(height, 220) }}>
              <table className="ui-chart-table">
                <caption className="ui-sr-only">{title}</caption>
                <thead>
                  <tr>
                    {table.columns.map((c) => (
                      <th key={c} scope="col">
                        {c}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {table.rows.map((row, i) => (
                    <tr key={i}>
                      {row.map((cell, j) => (
                        <td key={j}>{cell}</td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            children
          ))}
      </div>
    </Card>
  );
}
