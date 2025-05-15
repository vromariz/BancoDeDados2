
-- Banco de Dados: aquarismo

DROP DATABASE IF EXISTS aquarismo;
CREATE DATABASE aquarismo;
USE aquarismo;

-- Tabela cliente
CREATE TABLE cliente (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    sexo ENUM('M', 'F') NOT NULL,
    idade INT NOT NULL,
    nascimento DATE
);

-- Tabela produto
CREATE TABLE produto (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    tipo ENUM('Peixe', 'Planta', 'Acessorio') NOT NULL,
    valor DECIMAL(10, 2) NOT NULL,
    quantidade INT NOT NULL,
    descricao TEXT
);

CREATE TABLE funcionario (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100),
    idade INT,
    sexo ENUM('m', 'f', 'o') NOT NULL,
    cargo ENUM('vendedor', 'gerente', 'CEO') NOT NULL,
    salario DECIMAL(10,2) NOT NULL,
    nascimento DATE
);

-- Tabela venda
CREATE TABLE venda (
    id INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT,
    id_vendedor INT,
    data DATE,
    FOREIGN KEY (id_vendedor) REFERENCES funcionario(id),
    FOREIGN KEY (id_cliente) REFERENCES cliente(id)
);

-- Tabela venda_produto
CREATE TABLE venda_produto (
    id_venda INT,
    id_produto INT,
    quantidade INT,
    valor_unitario DECIMAL(10, 2),
    PRIMARY KEY (id_venda, id_produto),
    FOREIGN KEY (id_venda) REFERENCES venda(id),
    FOREIGN KEY (id_produto) REFERENCES produto(id)
);

-- Tabela clienteespecial
CREATE TABLE clienteespecial (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100),
    sexo ENUM('M', 'F'),
    idade INT,
    id_cliente INT UNIQUE,
    cashback DECIMAL(10,2),
    FOREIGN KEY (id_cliente) REFERENCES cliente(id)
);



-- Usuários e permissões
CREATE USER IF NOT EXISTS 'admin'@'localhost' IDENTIFIED BY 'admin123';
CREATE USER IF NOT EXISTS 'gerente'@'localhost' IDENTIFIED BY 'gerente123';
CREATE USER IF NOT EXISTS 'funcionario'@'localhost' IDENTIFIED BY 'func123';

GRANT ALL PRIVILEGES ON aquarismo.* TO 'admin'@'localhost';
GRANT SELECT, DELETE, UPDATE ON aquarismo.* TO 'gerente'@'localhost';
GRANT INSERT, SELECT ON aquarismo.venda TO 'funcionario'@'localhost';
GRANT INSERT, SELECT ON aquarismo.venda_produto TO 'funcionario'@'localhost';

DELIMITER //

CREATE TRIGGER trg_funcionario_especial
AFTER INSERT ON venda_produto
FOR EACH ROW
BEGIN
  DECLARE total_vendas DECIMAL(10,2);
  DECLARE bonus_total DECIMAL(10,2);
  DECLARE msg TEXT;

  SELECT SUM(vp.valor_unitario * vp.quantidade)
  INTO total_vendas
  FROM venda v
  JOIN venda_produto vp ON v.id = vp.id_venda
  WHERE v.id_vendedor = (SELECT id_vendedor FROM venda WHERE id = NEW.id_venda);

  IF total_vendas > 1000 THEN
    SET bonus_total = total_vendas * 0.05;
    INSERT IGNORE INTO funcionarioespecial (nome, cargo, id_funcionario, bonus)
    SELECT f.nome, f.cargo, f.id, bonus_total FROM funcionario f
    WHERE f.id = (SELECT id_vendedor FROM venda WHERE id = NEW.id_venda);
	
    set msg = CONCAT('Total bônus necessário: R$', bonus_total);
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
  END IF;
END //
DELIMITER ;


-- Trigger corrigida
DELIMITER //

CREATE TRIGGER trg_cliente_especial
AFTER INSERT ON venda_produto
FOR EACH ROW
BEGIN
  DECLARE total_gasto DECIMAL(10,2);
  DECLARE cashback_valor DECIMAL(10,2);
  DECLARE cid INT;
  DECLARE msg TEXT;

  SELECT v.id_cliente INTO cid 
  FROM venda v 
  WHERE v.id = NEW.id_venda;

  SELECT SUM(vp.valor_unitario * vp.quantidade)
  INTO total_gasto
  FROM venda v
  JOIN venda_produto vp ON v.id = vp.id_venda
  WHERE v.id_cliente = cid;

  IF total_gasto > 500 THEN
    SET cashback_valor = total_gasto * 0.02;

    INSERT INTO clienteespecial (nome, sexo, idade, id_cliente, cashback)
    SELECT c.nome, c.sexo, c.idade, c.id, cashback_valor 
    FROM cliente c 
    WHERE c.id = cid
    ON DUPLICATE KEY UPDATE cashback = VALUES(cashback);

	SET msg = CONCAT('Total cashback necessário: R$ ', cashback_valor);
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
  END IF;
END;
//

DELIMITER ;

DELIMITER //
CREATE TRIGGER trg_remover_cliente_especial
AFTER UPDATE ON clienteespecial
FOR EACH ROW
BEGIN
  IF NEW.cashback = 0 THEN
    DELETE FROM clienteespecial WHERE id = NEW.id;
  END IF;
END //
DELIMITER ;

CREATE VIEW vw_total_produto AS
SELECT p.nome AS produto, SUM(vp.quantidade) AS total_vendido, SUM(vp.quantidade * vp.valor_unitario) AS total_revenue
FROM produto p
JOIN venda_produto vp ON p.id = vp.id_produto
GROUP BY p.id;

CREATE VIEW vw_clientes_especiais_gasto AS
SELECT c.id, c.nome, SUM(vp.quantidade * vp.valor_unitario) AS total_gasto
FROM cliente c
JOIN venda v ON c.id = v.id_cliente
JOIN venda_produto vp ON v.id = vp.id_venda
WHERE c.id IN (SELECT id_cliente FROM clienteespecial)
GROUP BY c.id;

CREATE VIEW vw_total_vendas_funcionario AS
SELECT f.id, f.nome, SUM(vp.quantidade * vp.valor_unitario) AS total_vendas
FROM funcionario f
JOIN venda v ON f.id = v.id_vendedor
JOIN venda_produto vp ON v.id = vp.id_venda
GROUP BY f.id;

DELIMITER //
CREATE PROCEDURE reajuste(IN pcargo VARCHAR(50), IN percentual DECIMAL(5,2))
BEGIN
  UPDATE funcionario
  SET salario = salario + (salario * percentual / 100)
  WHERE cargo = pcargo;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sorteio()
BEGIN
  DECLARE sorteado INT;
  SELECT id INTO sorteado FROM cliente ORDER BY RAND() LIMIT 1;

  IF sorteado IN (SELECT id_cliente FROM clienteespecial) THEN
    SELECT CONCAT('Cliente ', sorteado, ' ganhou um voucher de R$200!') AS mensagem;
  ELSE
    SELECT CONCAT('Cliente ', sorteado, ' ganhou um voucher de R$100!') AS mensagem;
  END IF;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE venda(IN pid_produto INT, IN quantidade INT)
BEGIN
  UPDATE produto SET quantidade = quantidade - quantidade
  WHERE id = pid_produto AND quantidade >= quantidade;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE estatisticas()
BEGIN
  DECLARE id_mais INT;
  DECLARE id_menos INT;

  SELECT id_produto INTO id_mais
  FROM venda_produto
  GROUP BY id_produto
  ORDER BY SUM(quantidade) DESC
  LIMIT 1;

  SELECT id_produto INTO id_menos
  FROM venda_produto
  GROUP BY id_produto
  ORDER BY SUM(quantidade) ASC
  LIMIT 1;

  SELECT 'Mais vendido' AS tipo,
         p.nome,
         SUM(vp.quantidade) AS total,
         SUM(vp.quantidade * vp.valor_unitario) AS total_ganho,
         MONTH(v.data) AS mes
  FROM produto p
  JOIN venda_produto vp ON p.id = vp.id_produto
  JOIN venda v ON v.id = vp.id_venda
  WHERE p.id = id_mais
  GROUP BY mes;

  SELECT 'Menos vendido' AS tipo,
         p.nome,
         SUM(vp.quantidade) AS total,
         SUM(vp.quantidade * vp.valor_unitario) AS total_ganho,
         MONTH(v.data) AS mes
  FROM produto p
  JOIN venda_produto vp ON p.id = vp.id_produto
  JOIN venda v ON v.id = vp.id_venda
  WHERE p.id = id_menos
  GROUP BY mes;

  SELECT f.nome AS vendedor
  FROM funcionario f
  JOIN venda v ON f.id = v.id_vendedor
  JOIN venda_produto vp ON v.id = vp.id_venda
  WHERE vp.id_produto = id_mais
  GROUP BY f.id
  ORDER BY SUM(vp.quantidade) DESC
  LIMIT 1;
END //
DELIMITER ;

INSERT INTO funcionario (nome, idade, sexo, cargo, salario, nascimento) VALUES 
('João', 29, 'm', 'vendedor', 1800.00, '1995-04-10'),
('Mariana', 35, 'f', 'gerente', 3000.00, '1989-09-22'),
('Carlos', 45, 'm', 'CEO', 7000.00, '1979-01-01'),
('Fernanda', 27, 'f', 'vendedor', 1850.00, '1997-06-14'),
('Lucas', 31, 'm', 'vendedor', 1900.00, '1993-03-19');

INSERT INTO produto (nome, quantidade, descricao, valor) VALUES 
('Neon Cardinal', 20, 'Peixe de cardume pacífico, ideal para aquários plantados.', 12.90),
('Betta Splendens', 15, 'Peixe ornamental agressivo, manter isolado.', 25.00),
('Corydora Albina', 12, 'Peixe de fundo que ajuda na limpeza do aquário.', 18.50),
('Tetra Negro', 18, 'Peixe de cardume resistente, compatível com várias espécies.', 10.00),
('Platy Mickey', 25, 'Peixe pacífico, fácil reprodução.', 7.90),
('Guppy Cobra', 30, 'Peixe colorido, muito ativo e resistente.', 6.50),
('Molinésia Negra', 22, 'Peixe vivíparo que gosta de água levemente salobra.', 8.00),
('Barbo Cereja', 14, 'Peixe ativo e vibrante, ideal para comunitários.', 9.50),
('Disco Azul', 8, 'Peixe exigente, recomendado para aquaristas experientes.', 120.00),
('Ramirezi Azul Elétrico', 10, 'Ciclídeo anão colorido e pacífico.', 35.00),
('Caramujo Neritina', 40, 'Molusco limpador de algas, não se reproduz em água doce.', 5.50),
('Caramujo Tigre', 35, 'Molusco ornamental e útil contra algas.', 6.00),
('Ampulária Dourada', 20, 'Molusco grande que pode comer plantas.', 4.00),
('Red Cherry Shrimp', 50, 'Camarão ornamental que ajuda na limpeza.', 3.50),
('Amano Shrimp', 40, 'Camarão eficiente no controle de algas.', 5.00),
('Camarão Blue Dream', 30, 'Crustáceo decorativo e pacífico.', 4.50),
('Otocinclus Affinis', 15, 'Peixe pequeno e tímido, excelente comedor de algas.', 13.00),
('Cascudo Ancistrus', 10, 'Peixe de fundo comedor de algas, de pequeno porte.', 22.00),
('Kinguio Cometa', 16, 'Peixe de água fria, ideal para aquários grandes.', 19.90),
('Tanictis Albino', 20, 'Peixe de água fria, ideal para iniciantes.', 8.50);

INSERT INTO cliente (nome, sexo, idade, nascimento) VALUES 
('Juliana Souza', 'f', 21, '2003-04-12'),
('Carlos Mendes', 'm', 42, '1982-08-01'),
('Ana Lima', 'f', 34, '1990-07-03'),
('Marcos Pereira', 'm', 55, '1969-02-18'),
('Fernanda Oliveira', 'f', 27, '1997-05-09'),
('Lucas Silva', 'm', 38, '1986-11-20'),
('João Rocha', 'm', 25, '1999-09-30'),
('Patrícia Costa', 'f', 44, '1980-06-21'),
('Ricardo Fernandes', 'm', 36, '1988-01-10'),
('Paula Souza', 'f', 31, '1993-03-15'),
('Vinícius Santos', 'm', 28, '1996-07-25'),
('Camila Barros', 'f', 40, '1984-12-12'),
('Bruno Ferreira', 'm', 33, '1991-10-19'),
('Larissa Rocha', 'f', 22, '2002-06-06'),
('Thiago Mendes', 'm', 30, '1994-05-14'),
('Juliana Costa', 'f', 37, '1987-08-17'),
('Rafael Souza', 'm', 29, '1995-04-28'),
('Aline Oliveira', 'f', 26, '1998-09-02'),
('Eduardo Lima', 'm', 41, '1983-11-11'),
('Isabela Gomes', 'f', 24, '2000-01-20'),
('Mateus Silva', 'm', 39, '1985-03-27'),
('Cláudia Fernandes', 'f', 32, '1992-02-05'),
('Leonardo Rocha', 'm', 45, '1979-10-08'),
('Vanessa Costa', 'f', 35, '1989-12-30'),
('Gustavo Pereira', 'm', 23, '2001-04-04'),
('Roberta Lima', 'f', 43, '1981-07-16'),
('Danilo Souza', 'm', 31, '1993-06-03'),
('Helena Oliveira', 'f', 28, '1996-11-23'),
('Felipe Santos', 'm', 34, '1990-08-29'),
('Tatiane Mendes', 'f', 36, '1988-09-17'),
('Igor Silva', 'm', 27, '1997-10-22'),
('Daniela Barros', 'f', 20, '2004-05-25'),
('Alex Rocha', 'm', 33, '1991-12-01'),
('Carolina Costa', 'f', 38, '1986-04-13'),
('Bruna Souza', 'f', 29, '1995-09-08'),
('Gabriel Oliveira', 'm', 26, '1998-07-05'),
('Amanda Lima', 'f', 39, '1985-06-19'),
('Henrique Santos', 'm', 22, '2002-12-14'),
('Beatriz Mendes', 'f', 25, '1999-08-03'),
('Rodrigo Silva', 'm', 44, '1980-02-07'),
('Natália Costa', 'f', 30, '1994-01-09'),
('Fernando Rocha', 'm', 35, '1989-05-26'),
('Letícia Pereira', 'f', 37, '1987-03-03'),
('Diego Lima', 'm', 40, '1984-09-06'),
('Larissa Barros', 'f', 23, '2001-10-01'),
('Marcelo Souza', 'm', 41, '1983-08-27'),
('Sabrina Oliveira', 'f', 27, '1997-12-11'),
('Tiago Mendes', 'm', 34, '1990-06-24'),
('Érika Silva', 'f', 21, '2003-02-28'),
('Caio Costa', 'm', 32, '1992-04-18'),
('Yasmin Rocha', 'f', 19, '2005-03-12'),
('Hugo Santos', 'm', 36, '1988-05-30'),
('Joana Lima', 'f', 28, '1996-01-16'),
('Alan Fernandes', 'm', 43, '1981-11-07'),
('Michele Souza', 'f', 31, '1993-09-01'),
('Otávio Oliveira', 'm', 39, '1985-10-04'),
('Tatiane Rocha', 'f', 24, '2000-12-25'),
('Wesley Costa', 'm', 42, '1982-03-01'),
('Gabriela Lima', 'f', 22, '2002-02-10'),
('Pedro Mendes', 'm', 30, '1994-07-21'),
('Renata Silva', 'f', 40, '1984-05-08'),
('Fábio Souza', 'm', 27, '1997-02-15'),
('Nicole Pereira', 'f', 35, '1989-10-29'),
('Murilo Rocha', 'm', 33, '1991-01-11'),
('Cristiane Costa', 'f', 26, '1998-11-06'),
('Rogério Lima', 'm', 31, '1993-05-20'),
('Priscila Barros', 'f', 34, '1990-03-28'),
('Douglas Silva', 'm', 38, '1986-07-02'),
('Daniela Souza', 'f', 25, '1999-06-09'),
('Leandro Oliveira', 'm', 29, '1995-10-10'),
('Viviane Rocha', 'f', 36, '1988-02-14'),
('Samuel Costa', 'm', 41, '1983-01-23'),
('Juliana Lima', 'f', 20, '2004-09-04'),
('Caio Mendes', 'm', 23, '2001-06-06'),
('Tatiane Silva', 'f', 37, '1987-04-17'),
('André Souza', 'm', 28, '1996-12-29'),
('Rafaela Oliveira', 'f', 30, '1994-08-19'),
('Matheus Rocha', 'm', 26, '1998-03-22'),
('Débora Costa', 'f', 32, '1992-11-03'),
('Jean Lima', 'm', 35, '1989-06-11'),
('Amanda Barros', 'f', 27, '1997-01-26'),
('Vitor Silva', 'm', 39, '1985-09-15'),
('Elaine Souza', 'f', 31, '1993-07-07'),
('Luciano Oliveira', 'm', 40, '1984-02-02'),
('Talita Rocha', 'f', 24, '2000-10-13'),
('Anderson Costa', 'm', 36, '1988-08-31'),
('Daniele Lima', 'f', 33, '1991-04-01'),
('Rafael Mendes', 'm', 44, '1980-12-22'),
('Camila Silva', 'f', 21, '2003-11-09'),
('Ricardo Souza', 'm', 38, '1986-06-28'),
('Simone Oliveira', 'f', 29, '1995-02-06'),
('Bruno Rocha', 'm', 30, '1994-05-17'),
('Kelly Costa', 'f', 23, '2001-07-30'),
('Eduardo Lima', 'm', 28, '1996-01-02'),
('vinicius romariz', 'm',21, '2003-05-09'),
('Érica Fernandes', 'f', 34, '1990-02-15'),
('Gustavo Martins', 'm', 27, '1997-06-03'),
('Lúcia Andrade', 'f', 45, '1979-09-28'),
('Thiago Teixeira', 'm', 31, '1993-11-10'),
('Brenda Nogueira', 'f', 22, '2002-04-19');