import { useEffect, useState } from 'react';

import { env } from './env';
import { fetchPlans, plans as filePlans, type Plan } from './plans';

/**
 * Rejalar: avval fayldan (darhol), keyin serverdan (joriy narx bilan).
 *
 * Narx panelda o'zgartirilishi mumkin, fayldagi nusxa esa build
 * paytida qotib qoladi — shuning uchun serverdan so'raladi.
 */
export function usePlans(): { plans: Plan[]; loading: boolean } {
  const [plans, setPlans] = useState<Plan[]>(filePlans);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let alive = true;
    fetchPlans(env.apiBaseUrl).then((fresh) => {
      if (!alive) return;
      if (fresh) setPlans(fresh);
      setLoading(false);
    });
    return () => {
      alive = false;
    };
  }, []);

  return { plans, loading };
}
