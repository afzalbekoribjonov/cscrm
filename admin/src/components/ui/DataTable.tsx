import { useMemo, useState, type ReactNode } from 'react';

import { Icon } from '../Icon';
import { DropdownMenu, type MenuItem } from './DropdownMenu';
import { Select } from './Input';
import { IconButton } from './IconButton';
import { cx, paginate, sortRows, type PageSlice, type SortDir, type SortValue } from './logic';
import { Pagination } from './Pagination';
import { Skeleton } from './Skeleton';

export interface Column<T> {
  key: string;
  header: string;
  cell: (row: T) => ReactNode;
  /** Berilsa ustun saralanadi. */
  sortValue?: (row: T) => SortValue;
  align?: 'start' | 'end' | 'center';
  /** Telefonda kartaning sarlavhasi bo'ladi (yorliqsiz, katta). */
  primary?: boolean;
  /** Telefonda yashiriladi — kartani ikkinchi darajali ma'lumot bilan to'ldirmaslik. */
  hideOnMobile?: boolean;
  /** Raqamli ustun — raqamlar ustma-ust tekislanadi. */
  numeric?: boolean;
  width?: string;
}

export interface SortState {
  key: string;
  dir: SortDir;
}

/**
 * Jadval holati: saralash + sahifalash.
 *
 * Ota komponent holatni o'zi saqlashi ham mumkin (masalan, URL'da —
 * orqaga qaytganda filtr yo'qolmasligi uchun): `sort`/`page` va
 * ularning o'zgartiruvchilarini bersa, hook ularni ishlatadi.
 */
export function useTable<T>({
  rows,
  columns,
  pageSize = 20,
  initialSort,
  sort: controlledSort,
  onSortChange,
  page: controlledPage,
  onPageChange,
}: {
  rows: readonly T[] | null;
  columns: Column<T>[];
  pageSize?: number;
  initialSort?: SortState;
  sort?: SortState;
  onSortChange?: (s: SortState) => void;
  page?: number;
  onPageChange?: (p: number) => void;
}): {
  sort: SortState | undefined;
  setSort: (s: SortState) => void;
  setPage: (p: number) => void;
  slice: PageSlice<T> | null;
} {
  const [ownSort, setOwnSort] = useState<SortState | undefined>(initialSort);
  const [ownPage, setOwnPage] = useState(1);

  const sort = controlledSort ?? ownSort;
  const page = controlledPage ?? ownPage;

  const setSort = (s: SortState) => {
    (onSortChange ?? setOwnSort)(s);
    // Saralash o'zgarsa 3-sahifada qolish ma'nosiz — boshiga.
    (onPageChange ?? setOwnPage)(1);
  };
  const setPage = onPageChange ?? setOwnPage;

  const slice = useMemo(() => {
    if (!rows) return null;
    const column = sort ? columns.find((c) => c.key === sort.key) : undefined;
    const sorted = column?.sortValue && sort ? sortRows(rows, column.sortValue, sort.dir) : rows;
    return paginate(sorted, page, pageSize);
  }, [rows, columns, sort, page, pageSize]);

  return { sort, setSort, setPage, slice };
}

/**
 * Ma'lumotlar jadvali.
 *
 * * `rows === null` — birinchi yuklanish: skelet qatorlar (tuzilish
 *   darhol ko'rinadi, keyin sakramaydi);
 * * `refreshing` — qayta yuklash: eski ma'lumot xira turadi;
 * * bo'sh ro'yxat — `empty` (nima uchun bo'shligini aytadigan matn);
 * * telefonda har bir qator kartaga aylanadi (CSS), saralash esa
 *   sarlavhalar o'rniga alohida tanlovga o'tadi.
 */
export function DataTable<T>({
  caption,
  columns,
  rows,
  rowKey,
  sort,
  onSortChange,
  refreshing = false,
  empty,
  rowActions,
  pagination,
  skeletonRows = 5,
}: {
  /** Jadval nomi — ekran o'quvchi uchun (ko'rinmaydi). */
  caption: string;
  columns: Column<T>[];
  /** `null` — hali yuklanmagan. */
  rows: readonly T[] | null;
  rowKey: (row: T) => string;
  sort?: SortState;
  onSortChange?: (s: SortState) => void;
  refreshing?: boolean;
  empty?: ReactNode;
  rowActions?: (row: T) => MenuItem[];
  pagination?: { slice: PageSlice<unknown>; onPageChange: (p: number) => void };
  skeletonRows?: number;
}) {
  const sortable = columns.filter((c) => c.sortValue);
  const colCount = columns.length + (rowActions ? 1 : 0);

  const toggleSort = (key: string) => {
    if (!onSortChange) return;
    onSortChange(
      sort?.key === key
        ? { key, dir: sort.dir === 'asc' ? 'desc' : 'asc' }
        : { key, dir: 'asc' },
    );
  };

  return (
    <div className={cx('ui-table-wrap', refreshing && 'is-refreshing')} aria-busy={refreshing || rows === null}>
      {/* Bo'sh ro'yxatni saralashning ma'nosi yo'q. */}
      {onSortChange && sortable.length > 0 && rows?.length !== 0 && (
        <div className="ui-table-mobile-sort">
          <Select
            aria-label="Saralash"
            value={sort?.key ?? ''}
            onChange={(e) => onSortChange({ key: e.target.value, dir: sort?.dir ?? 'asc' })}
          >
            {!sort && <option value="">Saralash…</option>}
            {sortable.map((c) => (
              <option key={c.key} value={c.key}>
                {c.header}
              </option>
            ))}
          </Select>
          <IconButton
            icon={sort?.dir === 'desc' ? 'arrow-down' : 'arrow-up'}
            label={sort?.dir === 'desc' ? 'Kamayish tartibida' : 'O\'sish tartibida'}
            outline
            disabled={!sort}
            onClick={() =>
              sort && onSortChange({ key: sort.key, dir: sort.dir === 'asc' ? 'desc' : 'asc' })
            }
          />
        </div>
      )}

      <div className="ui-table-scroll">
        <table className="ui-table">
          <caption className="ui-sr-only">{caption}</caption>
          <thead>
            <tr>
              {columns.map((c) => {
                const active = sort?.key === c.key;
                const ariaSort = active ? (sort.dir === 'asc' ? 'ascending' : 'descending') : c.sortValue ? 'none' : undefined;
                return (
                  <th
                    key={c.key}
                    scope="col"
                    aria-sort={ariaSort}
                    className={cx(c.align === 'end' && 'is-end', c.align === 'center' && 'is-center')}
                    style={c.width ? { width: c.width } : undefined}
                  >
                    {c.sortValue && onSortChange ? (
                      <button type="button" onClick={() => toggleSort(c.key)}>
                        {c.header}
                        <span className="ui-table__sort-icon" aria-hidden="true">
                          <Icon
                            name={active && sort.dir === 'desc' ? 'arrow-down' : 'arrow-up'}
                            size={13}
                            strokeWidth={2.2}
                          />
                        </span>
                      </button>
                    ) : (
                      c.header
                    )}
                  </th>
                );
              })}
              {rowActions && (
                <th scope="col" className="ui-table__actions">
                  <span className="ui-sr-only">Amallar</span>
                </th>
              )}
            </tr>
          </thead>
          <tbody>
            {rows === null
              ? Array.from({ length: skeletonRows }, (_, i) => (
                  <tr key={`s${i}`}>
                    {columns.map((c) => (
                      <td
                        key={c.key}
                        data-label={c.header}
                        className={cx(c.primary && 'is-primary', c.hideOnMobile && 'is-hidden-mobile')}
                      >
                        <Skeleton width={c.primary ? '70%' : '55%'} />
                      </td>
                    ))}
                    {rowActions && <td className="ui-table__actions" />}
                  </tr>
                ))
              : rows.length === 0
                ? (
                  <tr>
                    <td colSpan={colCount} className="ui-table__empty">
                      {empty}
                    </td>
                  </tr>
                )
                : rows.map((row) => (
                  <tr key={rowKey(row)}>
                    {columns.map((c) => (
                      <td
                        key={c.key}
                        data-label={c.header}
                        className={cx(
                          c.primary && 'is-primary',
                          c.hideOnMobile && 'is-hidden-mobile',
                          c.align === 'end' && 'is-end',
                          c.align === 'center' && 'is-center',
                          c.numeric && 'is-numeric',
                        )}
                      >
                        {c.cell(row)}
                      </td>
                    ))}
                    {rowActions && (
                      <td className="ui-table__actions">
                        <DropdownMenu items={rowActions(row)} />
                      </td>
                    )}
                  </tr>
                ))}
          </tbody>
        </table>
      </div>

      {pagination && rows !== null && rows.length > 0 && (
        <Pagination slice={pagination.slice} onChange={pagination.onPageChange} />
      )}
    </div>
  );
}
