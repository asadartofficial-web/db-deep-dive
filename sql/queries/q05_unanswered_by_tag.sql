--- q05: Which established tags have the highest share of unanswered questions? ---
--- "Established" = at least 200 questions on that site, to keep one-hit tags out.

SELECT t.site,
       t.tag_name,
       COUNT(*) AS questions,
       COUNT(*) FILTER (WHERE p.answer_count = 0) AS unanswered_questions,
       ROUND(COUNT(*) FILTER (WHERE p.answer_count = 0) * 100.0 / COUNT(*), 1) AS unanswered_pct
FROM core.post_tags pt
JOIN core.tags  t ON t.tag_key  = pt.tag_key
JOIN core.posts p ON p.post_key = pt.post_key
WHERE p.post_type_id = 1
GROUP BY t.site, t.tag_name
HAVING COUNT(*) >= 200
ORDER BY unanswered_pct DESC, questions DESC
LIMIT 20
;
