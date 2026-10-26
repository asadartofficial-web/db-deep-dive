--- What is the share of unanswered questions? ---
Select site,
    extract(year FROM created_at) AS year,
    COUNT(*) AS total_questions,
    COUNT(*) FILTER (WHERE answer_count = 0) AS unanswered_questions,
    ROUND(COUNT(*) FILTER (WHERE answer_count = 0) * 100.0 / COUNT(*), 2) AS unanswered_share
    
FROM core.posts
WHERE post_type_id = 1
GROUP BY site, extract(year FROM created_at)
ORDER BY site, year;
