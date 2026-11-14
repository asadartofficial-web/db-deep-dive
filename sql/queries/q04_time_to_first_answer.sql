--- q04: How long do questions wait for their first answer, per site? ---

WITH first_answer AS (
    SELECT q.post_key,
           q.site,
           q.created_at AS question_at,
           MIN(a.created_at) AS first_answer_at
    FROM core.posts q
    JOIN core.posts a
      ON a.parent_key = q.post_key
     AND a.post_type_id = 2
    WHERE q.post_type_id = 1
    GROUP BY q.post_key, q.site, q.created_at
)
SELECT site,
       COUNT(*) AS answered_questions,
       ROUND(AVG(EXTRACT(EPOCH FROM (first_answer_at - question_at)) / 3600.0)::numeric, 1) AS avg_hours_to_first_answer,
       ROUND(percentile_cont(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (first_answer_at - question_at)))::numeric / 3600.0, 1) AS median_hours_to_first_answer
FROM first_answer
GROUP BY site
ORDER BY site
;
