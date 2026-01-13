-- =========================
-- KHỞI TẠO DATABASE
-- =========================
DROP DATABASE IF EXISTS social_network;
CREATE DATABASE social_network;
USE social_network;

-- =========================
-- TẠO BẢNG
-- =========================

CREATE TABLE Users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE Posts (
    post_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    content TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES Users(user_id)
);

CREATE TABLE Comments (
    comment_id INT AUTO_INCREMENT PRIMARY KEY,
    post_id INT NOT NULL,
    user_id INT NOT NULL,
    content TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (post_id) REFERENCES Posts(post_id),
    FOREIGN KEY (user_id) REFERENCES Users(user_id)
);

CREATE TABLE Friends (
    user_id INT NOT NULL,
    friend_id INT NOT NULL,
    status VARCHAR(20) CHECK (status IN ('pending','accepted')),
    FOREIGN KEY (user_id) REFERENCES Users(user_id),
    FOREIGN KEY (friend_id) REFERENCES Users(user_id)
);

CREATE TABLE Likes (
    user_id INT NOT NULL,
    post_id INT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES Users(user_id),
    FOREIGN KEY (post_id) REFERENCES Posts(post_id),
    UNIQUE (user_id, post_id)
);

-- =========================
-- BÀI 1: QUẢN LÝ NGƯỜI DÙNG
-- =========================

INSERT INTO Users(username, password, email)
VALUES ('an123','123456','an@gmail.com'),
       ('binh','123456','binh@gmail.com'),
       ('cuong','123456','cuong@gmail.com');

SELECT * FROM Users;

-- =========================
-- BÀI 2: VIEW CÔNG KHAI
-- =========================

CREATE OR REPLACE VIEW vw_public_users AS
SELECT user_id, username, created_at
FROM Users;

SELECT * FROM vw_public_users;

-- =========================
-- BÀI 3: INDEX TÌM KIẾM USER
-- =========================

CREATE INDEX idx_users_username ON Users(username);

SELECT * FROM Users WHERE username = 'an123';

-- =========================
-- BÀI 4: STORED PROCEDURE ĐĂNG BÀI
-- =========================

DELIMITER $$

CREATE PROCEDURE sp_create_post(
    IN p_user_id INT,
    IN p_content TEXT
)
BEGIN
    IF EXISTS (SELECT 1 FROM Users WHERE user_id = p_user_id) THEN
        INSERT INTO Posts(user_id, content)
        VALUES (p_user_id, p_content);
    ELSE
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'User không tồn tại';
    END IF;
END $$

DELIMITER ;

CALL sp_create_post(1, 'Bài viết đầu tiên');
CALL sp_create_post(1, 'Học SQL Stored Procedure');
CALL sp_create_post(2, 'MySQL rất hay');

-- =========================
-- BÀI 5: VIEW NEWS FEED
-- =========================

CREATE OR REPLACE VIEW vw_recent_posts AS
SELECT *
FROM Posts
WHERE created_at >= NOW() - INTERVAL 7 DAY;

SELECT * FROM vw_recent_posts;

-- =========================
-- BÀI 6: INDEX TỐI ƯU BÀI VIẾT
-- =========================

CREATE INDEX idx_posts_user ON Posts(user_id);
CREATE INDEX idx_posts_user_time ON Posts(user_id, created_at);

SELECT *
FROM Posts
WHERE user_id = 1
ORDER BY created_at DESC;

-- =========================
-- BÀI 7: THỐNG KÊ SỐ BÀI VIẾT
-- =========================

DELIMITER $$

CREATE PROCEDURE sp_count_posts(
    IN p_user_id INT,
    OUT p_total INT
)
BEGIN
    SELECT COUNT(*) INTO p_total
    FROM Posts
    WHERE user_id = p_user_id;
END $$

DELIMITER ;

CALL sp_count_posts(1, @total_posts);
SELECT @total_posts AS total_posts;

-- =========================
-- BÀI 8: VIEW WITH CHECK OPTION
-- =========================

CREATE OR REPLACE VIEW vw_active_users AS
SELECT *
FROM Users
WHERE email IS NOT NULL
WITH CHECK OPTION;

-- INSERT HỢP LỆ
INSERT INTO vw_active_users(username, password, email)
VALUES ('dung','123456','dung@gmail.com');

-- INSERT KHÔNG HỢP LỆ (BỊ CHẶN)
-- INSERT INTO vw_active_users(username, password, email)
-- VALUES ('fail','123456', NULL);

-- =========================
-- BÀI 9: STORED PROCEDURE KẾT BẠN
-- =========================

DELIMITER $$

CREATE PROCEDURE sp_add_friend(
    IN p_user_id INT,
    IN p_friend_id INT
)
BEGIN
    IF p_user_id = p_friend_id THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Không thể kết bạn với chính mình';
    ELSE
        INSERT INTO Friends(user_id, friend_id, status)
        VALUES (p_user_id, p_friend_id, 'pending');
    END IF;
END $$

DELIMITER ;

CALL sp_add_friend(1, 2);

-- =========================
-- BÀI 10: GỢI Ý BẠN BÈ
-- =========================

DELIMITER $$

CREATE PROCEDURE sp_suggest_friends(
    IN p_user_id INT,
    INOUT p_limit INT
)
BEGIN
    SELECT user_id, username
    FROM Users
    WHERE user_id != p_user_id
    LIMIT p_limit;
END $$

DELIMITER ;

SET @limit = 2;
CALL sp_suggest_friends(1, @limit);

-- =========================
-- BÀI 11: TOP BÀI VIẾT NHIỀU LIKE
-- =========================

CREATE INDEX idx_likes_post ON Likes(post_id);

CREATE OR REPLACE VIEW vw_top_posts AS
SELECT post_id, COUNT(*) AS total_likes
FROM Likes
GROUP BY post_id
ORDER BY total_likes DESC
LIMIT 5;

-- =========================
-- BÀI 12: QUẢN LÝ BÌNH LUẬN
-- =========================

DELIMITER $$

CREATE PROCEDURE sp_add_comment(
    IN p_user_id INT,
    IN p_post_id INT,
    IN p_content TEXT
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Users WHERE user_id = p_user_id) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'User không tồn tại';
    ELSEIF NOT EXISTS (SELECT 1 FROM Posts WHERE post_id = p_post_id) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Post không tồn tại';
    ELSE
        INSERT INTO Comments(user_id, post_id, content)
        VALUES (p_user_id, p_post_id, p_content);
    END IF;
END $$

DELIMITER ;

CALL sp_add_comment(2, 1, 'Bài viết hay');

CREATE OR REPLACE VIEW vw_post_comments AS
SELECT c.content, u.username, c.created_at
FROM Comments c
JOIN Users u ON c.user_id = u.user_id;

SELECT * FROM vw_post_comments;

-- =========================
-- BÀI 13: QUẢN LÝ LƯỢT THÍCH
-- =========================

DELIMITER $$

CREATE PROCEDURE sp_like_post(
    IN p_user_id INT,
    IN p_post_id INT
)
BEGIN
    IF EXISTS (
        SELECT 1 FROM Likes
        WHERE user_id = p_user_id AND post_id = p_post_id
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Đã thích bài viết này';
    ELSE
        INSERT INTO Likes(user_id, post_id)
        VALUES (p_user_id, p_post_id);
    END IF;
END $$

DELIMITER ;

CALL sp_like_post(1, 1);
CALL sp_like_post(2, 1);

CREATE OR REPLACE VIEW vw_post_likes AS
SELECT post_id, COUNT(*) AS total_likes
FROM Likes
GROUP BY post_id;