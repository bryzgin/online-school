/* Затраты на рекламу в динамике */
with ads as (
    select
        to_char(vk.campaign_date, 'DD-MM-YYYY') as campaign_date,
        vk.utm_source,
        vk.utm_medium,
        vk.utm_campaign,
        sum(vk.daily_spent) as total_cost
    from vk_ads as vk
    group by
        to_char(vk.campaign_date, 'DD-MM-YYYY'),
        vk.utm_source,
        vk.utm_medium,
        vk.utm_campaign
    union
    select
        to_char(ya.campaign_date, 'DD-MM-YYYY') as campaign_date,
        ya.utm_source,
        ya.utm_medium,
        ya.utm_campaign,
        sum(ya.daily_spent) as total_cost
    from ya_ads as ya
    group by
        to_char(ya.campaign_date, 'DD-MM-YYYY'),
        ya.utm_source,
        ya.utm_medium,
        ya.utm_campaign
)

select
    utm_source,
    campaign_date,
    sum(total_cost) as total_cost
from ads
group by
    campaign_date,
    utm_source
order by
    utm_source,
    campaign_date;

/* Конверсия клика в лид */
with ads as (
    select
        to_char(vk.campaign_date, 'DD-MM-YYYY') as campaign_date,
        vk.utm_source,
        vk.utm_medium,
        vk.utm_campaign,
        sum(vk.daily_spent) as total_cost
    from vk_ads as vk
    group by
        to_char(vk.campaign_date, 'DD-MM-YYYY'),
        vk.utm_source,
        vk.utm_medium,
        vk.utm_campaign
    union
    select
        to_char(ya.campaign_date, 'DD-MM-YYYY') as campaign_date,
        ya.utm_source,
        ya.utm_medium,
        ya.utm_campaign,
        sum(ya.daily_spent) as total_cost
    from ya_ads as ya
    group by
        to_char(ya.campaign_date, 'DD-MM-YYYY'),
        ya.utm_source,
        ya.utm_medium,
        ya.utm_campaign
)

select
    utm_source,
    campaign_date,
    sum(total_cost) as total_cost
from ads
group by
    campaign_date,
    utm_source
order by
    utm_source,
    campaign_date;

with query as (
    select
        s.visitor_id,
        s.visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        row_number()
        over (
            partition by s.visitor_id
            order by s.visit_date desc
        )
        as visit_rank
    from sessions as s
    where s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
),

lpc as (
    select
        q.visitor_id,
        q.utm_source,
        q.utm_medium,
        q.utm_campaign,
        l.lead_id,
        l.amount,
        l.closing_reason,
        l.status_id,
        to_char(q.visit_date, 'DD-MM-YYYY') as visit_date,
        to_char(l.created_at, 'DD-MM-YYYY') as created_at
    from query as q
    left join leads as l
        on
            q.visitor_id = l.visitor_id
            and q.visit_date <= l.created_at
    where q.visit_rank = 1
    order by
        l.amount desc nulls last,
        q.visit_date asc,
        q.utm_source asc,
        q.utm_medium asc,
        q.utm_campaign asc
),

click_to_lead as (
    select
        cast(count(distinct visitor_id) as numeric) as visits_count,
        cast(count(distinct lead_id) as numeric) as leads_count
    from lpc
)

select
    visits_count,
    leads_count,
    round(leads_count / visits_count * 100, 2) as conv
from click_to_lead;

/* Конверсия из лида в оплату */
with query as (
    select
        s.visitor_id,
        s.visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        row_number()
        over (
            partition by s.visitor_id
            order by s.visit_date desc
        )
        as visit_rank
    from sessions as s
    where s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
),

lpc as (
    select
        q.visitor_id,
        q.utm_source,
        q.utm_medium,
        q.utm_campaign,
        l.lead_id,
        l.amount,
        l.closing_reason,
        l.status_id,
        to_char(q.visit_date, 'DD-MM-YYYY') as visit_date,
        to_char(l.created_at, 'DD-MM-YYYY') as created_at
    from query as q
    left join leads as l
        on
            q.visitor_id = l.visitor_id
            and q.visit_date <= l.created_at
    where q.visit_rank = 1
    order by
        l.amount desc nulls last,
        q.visit_date asc,
        q.utm_source asc,
        q.utm_medium asc,
        q.utm_campaign asc
),

lead_to_purchase as (
    select
        cast(count(distinct lpc.lead_id) as numeric) as leads_count,
        cast(
            count(distinct lpc.lead_id) filter (
                where lpc.closing_reason = 'Успешно реализовано'
                or lpc.status_id = 142
            ) as numeric
        ) as purchases_count
    from lpc
)

select
    leads_count,
    purchases_count,
    round(purchases_count / leads_count * 100, 2) as conv
from lead_to_purchase;

/* Корреляция компания - органика */
with query as (
    select
        s.visitor_id,
        s.visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        row_number()
        over (
            partition by s.visitor_id
            order by s.visit_date desc
        )
        as visit_rank
    from sessions as s
    where
        s.medium in (
            'cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social', 'organic'
        )
),

lpc as (
    select
        q.visitor_id,
        q.utm_source,
        q.utm_medium,
        q.utm_campaign,
        l.lead_id,
        l.amount,
        l.closing_reason,
        l.status_id,
        to_char(q.visit_date, 'DD-MM-YYYY') as visit_date,
        to_char(l.created_at, 'DD-MM-YYYY') as created_at
    from query as q
    left join leads as l
        on
            q.visitor_id = l.visitor_id
            and q.visit_date <= l.created_at
    where q.visit_rank = 1
    order by
        l.amount desc nulls last,
        q.visit_date asc,
        q.utm_source asc,
        q.utm_medium asc,
        q.utm_campaign asc
),

organic as (
    select
        visit_date,
        count(distinct visitor_id) as organic_visitors_count
    from lpc
    where utm_medium = 'organic'
    group by visit_date
),

campaign as (
    select
        visit_date,
        count(distinct visitor_id) as campaign_visitors_count
    from lpc
    where utm_medium != 'organic'
    group by visit_date
)

select
    o.visit_date,
    o.organic_visitors_count,
    c.campaign_visitors_count
from organic as o
inner join campaign as c
    on o.visit_date = c.visit_date;

/* Интервал закрытия 90% лидов */
with query as (
    select
        s.visitor_id,
        s.visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        row_number()
        over (
            partition by s.visitor_id
            order by s.visit_date desc
        )
        as visit_rank
    from sessions as s
    where s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
),

lpc as (
    select
        q.visitor_id,
        q.visit_date,
        q.utm_source,
        q.utm_medium,
        q.utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        date_part('day', l.created_at - q.visit_date) as days_diff
    from query as q
    left join leads as l
        on
            q.visitor_id = l.visitor_id
            and q.visit_date <= l.created_at
    where q.visit_rank = 1
    order by
        l.amount desc nulls last,
        q.visit_date asc,
        q.utm_source asc,
        q.utm_medium asc,
        q.utm_campaign asc
)

select
    lpc.lead_id,
    lpc.days_diff,
    to_char(lpc.visit_date, 'DD-MM-YYYY') as visit_date,
    to_char(lpc.created_at, 'DD-MM-YYYY') as created_at,
    ntile(10) over (
        partition by lpc.days_diff order by lpc.days_diff
    ) as closing_ntile
from lpc
where
    lpc.closing_reason = 'Успешно реализовано'
    or lpc.status_id = 142;

/* Метрики */
with query as (
    select
        s.visitor_id,
        s.visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        row_number()
        over (
            partition by s.visitor_id
            order by s.visit_date desc
        )
        as visit_rank
    from sessions as s
    where s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
),

last_paid_click as (
    select
        q.visitor_id,
        q.utm_source,
        q.utm_medium,
        q.utm_campaign,
        l.lead_id,
        l.amount,
        l.closing_reason,
        l.status_id,
        to_char(q.visit_date, 'DD-MM-YYYY') as visit_date
    from query as q
    left join leads as l
        on
            q.visitor_id = l.visitor_id
            and q.visit_date <= l.created_at
    where q.visit_rank = 1
    order by
        l.amount desc nulls last,
        q.visit_date asc,
        q.utm_source asc,
        q.utm_medium asc,
        q.utm_campaign asc
),

ads as (
    select
        vk.utm_source,
        vk.utm_medium,
        vk.utm_campaign,
        sum(vk.daily_spent) as total_cost,
        to_char(vk.campaign_date, 'DD-MM-YYYY') as campaign_date
    from vk_ads as vk
    group by
        vk.utm_source,
        vk.utm_medium,
        vk.utm_campaign,
        to_char(vk.campaign_date, 'DD-MM-YYYY')
    union
    select
        ya.utm_source,
        ya.utm_medium,
        ya.utm_campaign,
        sum(ya.daily_spent) as total_cost,
        to_char(ya.campaign_date, 'DD-MM-YYYY') as campaign_date
    from ya_ads as ya
    group by
        ya.utm_source,
        ya.utm_medium,
        ya.utm_campaign,
        to_char(ya.campaign_date, 'DD-MM-YYYY')
),

calc as (
    select
        lpc.visit_date,
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign,
        count(distinct lpc.visitor_id) as visitors_count,
        count(distinct lpc.lead_id) as leads_count,
        count(distinct lpc.lead_id) filter (
            where lpc.closing_reason = 'Успешно реализовано'
            or lpc.status_id = 142
        ) as purchases_count,
        sum(lpc.amount) as revenue
    from last_paid_click as lpc
    group by
        lpc.visit_date,
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign
),

metrics as (
    select
        c.utm_source,
        c.utm_medium,
        c.utm_campaign,
        c.visitors_count,
        a.total_cost,
        c.leads_count,
        c.purchases_count,
        c.revenue
    from calc as c
    left join ads as a
        on
            c.visit_date = a.campaign_date
            and c.utm_source = a.utm_source
            and c.utm_medium = a.utm_medium
            and c.utm_campaign = a.utm_campaign
    order by
        c.revenue desc nulls last,
        c.visitors_count desc,
        c.utm_source asc,
        c.utm_medium asc,
        c.utm_campaign asc
),

agg_metrics as (
    select
        utm_source,
        sum(visitors_count) as visitors_count,
        sum(leads_count) as leads_count,
        sum(purchases_count) as purchases_count,
        sum(total_cost) as total_cost,
        sum(revenue) as revenue
    from metrics
    where utm_source = 'yandex' or utm_source = 'vk'
    group by
        utm_source
)

select
    utm_source,
    visitors_count,
    leads_count,
    purchases_count,
    total_cost,
    revenue,
    round(total_cost / visitors_count) as cpu,
    round(total_cost / leads_count) as cpl,
    round(total_cost / purchases_count) as cppu,
    round(((revenue - total_cost) / total_cost * 100)) as roi
from agg_metrics;
