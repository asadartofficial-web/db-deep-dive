--- q01: New Questions per month, Per Site ---

Select site,
       MIN(created_at) as first_post,
       COUNT(*) AS questions
FROM core.posts
WHERE post_type_id = 1
GROUP BY site, MIN(created_at)
ORDER BY site, first_post
;
