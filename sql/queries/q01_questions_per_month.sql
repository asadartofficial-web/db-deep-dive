--- q01: New questions per month, per site ---

SELECT site,
       date_trunc('month', created_at) AS month,
       COUNT(*) AS questions
FROM core.posts
WHERE post_type_id = 1
GROUP BY site, date_trunc('month', created_at)
ORDER BY site, month
;
