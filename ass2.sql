-- ============================================================
-- 1. Non-optimized query
-- ============================================================
EXPLAIN ANALYZE
select
    min_data.product_category as min_category_name,
    min_data.cnt as min_orders_count,
    max_data.product_category as max_category_name,
    max_data.cnt as max_orders_count
from (
    select p.product_category, COUNT(*) AS cnt
    from opt_orders o
    left join opt_clients c 
    on o.client_id = c.id
    left join opt_products p 
    on o.product_id = p.product_id
    where c.status = 'active' 
    and o.order_date >= DATE '2023-01-01' 
    and o.order_date <= DATE '2023-12-31'
    group by p.product_category
    having COUNT(*) = (
        select MIN(cnt)
        from (
            select COUNT(*) as cnt
            from opt_orders o2
            left join opt_clients c2 
            on o2.client_id = c2.id
            left join opt_products p2 
            on o2.product_id = p2.product_id
            where c2.status = 'active' 
            and o2.order_date >= DATE '2023-01-01' 
            and o2.order_date <= DATE '2023-12-31'
            group by p2.product_category
        ) as sub_min
    )
    limit 1
) as min_data
cross join (
    select p.product_category, COUNT(*) as cnt
    from opt_orders o
    left join opt_clients c 
    on o.client_id = c.id
    left join opt_products p 
    on o.product_id = p.product_id
    where c.status = 'active' 
      and o.order_date >= DATE '2023-01-01' 
      and o.order_date <= DATE '2023-12-31'
    group by p.product_category
    having COUNT(*) = (
        select MAX(cnt)
        from (
            select COUNT(*) as cnt
            from opt_orders o3
            left join opt_clients c3 
            on o3.client_id = c3.id
            left join opt_products p3 
            on o3.product_id = p3.product_id
            where c3.status = 'active' 
              and o3.order_date >= DATE '2023-01-01' 
              and o3.order_date <= DATE '2023-12-31'
            group by p3.product_category
        ) as sub_max
    )
    limit 1
) as max_data;
-- ============================================================
-- 2. Indexes for optimization
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_opt_orders_order_date ON opt_orders(order_date);
CREATE INDEX IF NOT EXISTS idx_opt_orders_client_id ON opt_orders(client_id);
CREATE INDEX IF NOT EXISTS idx_opt_orders_product_id ON opt_orders(product_id);
CREATE INDEX IF NOT EXISTS idx_opt_clients_status ON opt_clients(status);
CREATE INDEX IF NOT EXISTS idx_opt_products_category ON opt_products(product_category);

SET enable_indexscan = OFF;
SET enable_bitmapscan = OFF;

-- ============================================================
-- 3. Optimized query
-- ============================================================

EXPLAIN ANALYZE
with category_counts as (
    select 
        p.product_category, 
        COUNT(*) AS cnt
    from opt_orders o
    left join opt_clients c 
    on o.client_id = c.id
    left join opt_products p 
    on o.product_id = p.product_id
    where c.status = 'active' 
      and o.order_date >= DATE '2023-01-01' 
      and o.order_date <= DATE '2023-12-31'
    group by 1
),
ranked_categories as (
    select 
        product_category, 
        cnt,
        ROW_NUMBER() over (order by cnt asc, product_category asc) as min_rn,
        ROW_NUMBER() over (order by cnt desc, product_category asc) as max_rn
    from category_counts
)
select
    MAX(case when min_rn = 1 then product_category end) as min_category_name,
    MAX(case when min_rn = 1 then cnt end) as min_orders_count,
    MAX(case when max_rn = 1 then product_category end) as max_category_name,
    MAX(case when max_rn = 1 then cnt end) as max_orders_count
from ranked_categories;

RESET enable_indexscan;
RESET enable_bitmapscan;
