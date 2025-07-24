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
        to_char(q.visit_date, 'YYYY-MM-DD') as visit_date
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
        to_char(vk.campaign_date, 'YYYY-MM-DD') as campaign_date,
        vk.utm_source,
        vk.utm_medium,
        vk.utm_campaign,
        sum(vk.daily_spent) as total_cost
    from vk_ads as vk
    group by
        to_char(vk.campaign_date, 'YYYY-MM-DD'),
        vk.utm_source,
        vk.utm_medium,
        vk.utm_campaign
    union
    select
        to_char(ya.campaign_date, 'YYYY-MM-DD') as campaign_date,
        ya.utm_source,
        ya.utm_medium,
        ya.utm_campaign,
        sum(ya.daily_spent) as total_cost
    from ya_ads as ya
    group by
        to_char(ya.campaign_date, 'YYYY-MM-DD'),
        ya.utm_source,
        ya.utm_medium,
        ya.utm_campaign
),

calc as (
    select
        lpc.visit_date,
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign,
        count(distinct lpc.visitor_id) as visitors_count,
        count(lpc.lead_id) as leads_count,
        count(lpc.lead_id) filter (
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
)

select
    c.visit_date,
    c.visitors_count,
    c.utm_source,
    c.utm_medium,
    c.utm_campaign,
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
    c.visit_date asc,
    c.visitors_count desc,
    c.utm_source asc,
    c.utm_medium asc,
    c.utm_campaign asc
limit 15;
