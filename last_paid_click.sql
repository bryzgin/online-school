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
)

select
    q.visitor_id,
    q.visit_date as visit_date,
    q.utm_source,
    q.utm_medium,
    q.utm_campaign,
    l.lead_id,
    l.created_at as created_at,
    l.amount,
    l.closing_reason,
    l.status_id
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
limit 10;
