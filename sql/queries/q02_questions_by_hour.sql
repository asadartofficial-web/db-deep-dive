--- Which hours of the day do people post? ---
 SELECT site,
        extract(hour from created_at) as hour_of_day,
        count(*) as questions
From core.posts
Where post_type_id = 1
GROUP BY site, extract(hour from created_at)
ORDER BY site, hour_of_day;