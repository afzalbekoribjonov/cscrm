import {
  Alert,
  Badge,
  Button,
  DataTable,
  EmptyState,
  PageHeader,
  Stack,
  useTable,
  type Column,
} from '@/components/ui';
import type { CabinetEmployee } from '@/lib/cabinet-types';
import { formatDay, formatRelative } from '@/lib/dates';
import { formatPhone } from '@/lib/format';
import { useApi } from '@/lib/use-api';

const COLUMNS: Column<CabinetEmployee>[] = [
  {
    key: 'name',
    header: 'Xodim',
    primary: true,
    sortValue: (e) => e.name,
    cell: (e) => (
      <>
        <span className="ui-table__primary">{e.name}</span>
        <span className="ui-table__sub">{e.phone ? formatPhone(e.phone) : '—'}</span>
      </>
    ),
  },
  {
    key: 'state',
    header: 'Holat',
    sortValue: (e) => (e.active ? 0 : 1),
    cell: (e) =>
      e.active ? (
        <Badge tone="success" dot>
          Faol
        </Badge>
      ) : (
        <Badge tone="neutral" dot>
          O'chirilgan
        </Badge>
      ),
  },
  {
    key: 'last',
    header: 'Oxirgi faollik',
    sortValue: (e) => e.lastActiveAt,
    cell: (e) => (e.lastActiveAt ? formatRelative(e.lastActiveAt) : <span className="ui-muted">Hali kirmagan</span>),
  },
  {
    key: 'created',
    header: 'Qo\'shilgan',
    hideOnMobile: true,
    sortValue: (e) => e.createdAt,
    cell: (e) => (e.createdAt ? formatDay(e.createdAt) : '—'),
  },
];

/**
 * Xodimlar — ko'rish uchun.
 *
 * Qo'shish, PIN va vakolatlar ILOVADA: xodim telefon raqami va PIN bilan
 * ilovaga kiradi, sozlamalari ham o'sha yerda. Ikki joyda boshqarish
 * bir-biriga zid o'zgarishlarga olib kelardi.
 */
export function CabinetEmployees() {
  const { data, error, loading, refreshing, reload } = useApi(
    '/api/v1/cabinet/employees',
    (j) => (j as { employees: CabinetEmployee[] }).employees,
  );
  const table = useTable({ rows: data, columns: COLUMNS, pageSize: 50, initialSort: { key: 'last', dir: 'desc' } });
  const active = data?.filter((e) => e.active).length ?? 0;

  return (
    <>
      <PageHeader
        title="Xodimlar"
        description={data ? `${data.length} ta, faol: ${active}` : 'Yuklanmoqda…'}
        actions={
          <Button variant="outline" size="sm" icon="refresh" loading={refreshing} onClick={reload}>
            Yangilash
          </Button>
        }
      />
      <Stack gap={4}>
        <Alert tone="info">Xodim qo'shish, PIN va vakolatlarni o'zgartirish — ilovadagi «Xodimlar» bo'limida.</Alert>
        {error && !data ? (
          <Alert
            tone="danger"
            action={
              <Button variant="outline" size="sm" icon="refresh" onClick={reload}>
                Qayta urinish
              </Button>
            }
          >
            {error}
          </Alert>
        ) : (
          <DataTable
            caption="Xodimlar"
            columns={COLUMNS}
            rows={loading ? null : (table.slice?.rows ?? null)}
            rowKey={(e) => e.id}
            sort={table.sort}
            onSortChange={table.setSort}
            refreshing={refreshing}
            pagination={table.slice ? { slice: table.slice, onPageChange: table.setPage } : undefined}
            empty={
              <EmptyState
                icon="people"
                title="Hali xodim yo'q"
                description="Ilovadagi «Xodimlar» bo'limidan qo'shing — ular shu yerda ko'rinadi."
                compact
              />
            }
          />
        )}
      </Stack>
    </>
  );
}
