import { Icon } from '../Icon';
import { formatNumber } from '@/lib/format';
import { cx, pageRange, type PageSlice } from './logic';

/**
 * Sahifalash.
 *
 * Chapda — "41–60 / 134 ta" (qancha borligini sahifalarni bosmasdan
 * bilish), o'ngda — sahifalar. Telefonda raqamlar o'rniga "3 / 7".
 * Bitta sahifa bo'lsa tugmalar ko'rsatilmaydi, lekin jami soni qoladi.
 */
export function Pagination({
  slice,
  onChange,
}: {
  slice: PageSlice<unknown>;
  onChange: (page: number) => void;
}) {
  const { page, pageCount, from, to, total } = slice;

  return (
    <nav className="ui-pagination" aria-label="Sahifalar">
      <span className="ui-pagination__summary">
        {from}–{to} / {formatNumber(total)} ta
      </span>

      {pageCount > 1 && (
        <div className="ui-pagination__pages">
          <button
            type="button"
            className="ui-page-btn"
            onClick={() => onChange(page - 1)}
            disabled={page <= 1}
            aria-label="Oldingi sahifa"
          >
            <Icon name="chevron-left" size={16} />
          </button>

          {pageRange(page, pageCount).map((item, i) =>
            item === 'gap' ? (
              <span key={`g${i}`} className="ui-page-gap" aria-hidden="true">
                …
              </span>
            ) : (
              <button
                key={item}
                type="button"
                className={cx('ui-page-btn', 'is-number')}
                aria-current={item === page ? 'page' : undefined}
                aria-label={`${item}-sahifa`}
                onClick={() => onChange(item)}
              >
                {item}
              </button>
            ),
          )}

          <span className="ui-pagination__compact" aria-hidden="true">
            {page} / {pageCount}
          </span>

          <button
            type="button"
            className="ui-page-btn"
            onClick={() => onChange(page + 1)}
            disabled={page >= pageCount}
            aria-label="Keyingi sahifa"
          >
            <Icon name="chevron-right" size={16} />
          </button>
        </div>
      )}
    </nav>
  );
}
