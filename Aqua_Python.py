import mysql.connector

# Conexão inicial (sem selecionar banco ainda)
conn = mysql.connector.connect(
    host="localhost",
    user="root",
    password="123123"
)
cursor = conn.cursor()

# Criar banco de dados
cursor.execute("CREATE DATABASE IF NOT EXISTS teste")
cursor.execute("USE teste")

# Tabelas
tabelas = [
    """
    CREATE TABLE cliente (
        id INT AUTO_INCREMENT PRIMARY KEY,
        nome VARCHAR(100),
        sexo ENUM('m', 'f', 'o') NOT NULL,
        idade INT,
        nascimento DATE
    )
    """,
    """
    CREATE TABLE produto (
        id INT AUTO_INCREMENT PRIMARY KEY,
        nome VARCHAR(100),
        quantidade INT,
        descricao TEXT,
        valor DECIMAL(10,2)
    )
    """,
    """
    CREATE TABLE funcionario (
        id INT AUTO_INCREMENT PRIMARY KEY,
        nome VARCHAR(100),
        idade INT,
        sexo ENUM('m', 'f', 'o') NOT NULL,
        cargo ENUM('vendedor', 'gerente', 'CEO') NOT NULL,
        salario DECIMAL(10,2),
        nascimento DATE
    )
    """,
    """
    CREATE TABLE venda (
        id INT AUTO_INCREMENT PRIMARY KEY,
        id_vendedor INT,
        id_cliente INT,
        data DATE,
        FOREIGN KEY (id_vendedor) REFERENCES funcionario(id),
        FOREIGN KEY (id_cliente) REFERENCES cliente(id)
    )
    """,
    """
    CREATE TABLE venda_produto (
        id_venda INT,
        id_produto INT,
        quantidade INT,
        valor_unitario DECIMAL(10,2),
        FOREIGN KEY (id_venda) REFERENCES venda(id),
        FOREIGN KEY (id_produto) REFERENCES produto(id)
    )
    """,
    """
    CREATE TABLE clienteespecial (
        id INT AUTO_INCREMENT PRIMARY KEY,
        nome VARCHAR(100),
        sexo ENUM('m', 'f', 'o') NOT NULL,
        idade INT,
        id_cliente INT UNIQUE,
        cashback DECIMAL(10,2) DEFAULT 0.00,
        FOREIGN KEY (id_cliente) REFERENCES cliente(id)
    )
    """,
    """
    CREATE TABLE funcionarioespecial (
        id INT AUTO_INCREMENT PRIMARY KEY,
        nome VARCHAR(100),
        cargo VARCHAR(50),
        id_funcionario INT UNIQUE,
        bonus DECIMAL(10,2),
        FOREIGN KEY (id_funcionario) REFERENCES funcionario(id)
    )
    """
]

for t in tabelas:
    cursor.execute(t)

# Inserir dados de exemplo (limitado para brevidade)
cursor.execute("""
    INSERT INTO funcionario (nome, idade, sexo, cargo, salario, nascimento) VALUES 
    ('João', 29, 'm', 'vendedor', 1800.00, '1995-04-10'),
    ('Mariana', 35, 'f', 'gerente', 3000.00, '1989-09-22')
""")

cursor.execute("""
    INSERT INTO cliente (nome, sexo, idade, nascimento) VALUES 
    ('Juliana Souza', 'f', 21, '2003-04-12'),
    ('Carlos Mendes', 'm', 42, '1982-08-01')
""")

cursor.execute("""
    INSERT INTO produto (nome, quantidade, descricao, valor) VALUES 
    ('Neon Cardinal', 20, 'Peixe de cardume pacífico', 12.90),
    ('Betta Splendens', 15, 'Peixe ornamental agressivo', 25.00)
""")

conn.commit()

# Views
cursor.execute("""
    CREATE VIEW vw_total_produto AS
    SELECT p.nome AS produto, SUM(vp.quantidade) AS total_vendido, SUM(vp.quantidade * vp.valor_unitario) AS total_revenue
    FROM produto p
    JOIN venda_produto vp ON p.id = vp.id_produto
    GROUP BY p.id
""")

# Procedures
cursor.execute("DROP PROCEDURE IF EXISTS reajuste")
cursor.execute("""
    CREATE PROCEDURE reajuste(IN pcargo VARCHAR(50), IN percentual DECIMAL(5,2))
    BEGIN
      UPDATE funcionario
      SET salario = salario + (salario * percentual / 100)
      WHERE cargo = pcargo;
    END
""")

cursor.execute("DROP PROCEDURE IF EXISTS sorteio")
cursor.execute("""
    CREATE PROCEDURE sorteio()
    BEGIN
      DECLARE sorteado INT;
      SELECT id INTO sorteado FROM cliente ORDER BY RAND() LIMIT 1;

      IF sorteado IN (SELECT id_cliente FROM clienteespecial) THEN
        SELECT CONCAT('Cliente ', sorteado, ' ganhou um voucher de R$200!') AS mensagem;
      ELSE
        SELECT CONCAT('Cliente ', sorteado, ' ganhou um voucher de R$100!') AS mensagem;
      END IF;
    END
""")

cursor.execute("DROP PROCEDURE IF EXISTS venda")
cursor.execute("""
    CREATE PROCEDURE venda(IN p_id_produto INT, IN p_quantidade INT)
    BEGIN
      UPDATE produto 
      SET quantidade = quantidade - p_quantidade
      WHERE id = p_id_produto AND quantidade >= p_quantidade;
    END
""")

# Triggers
cursor.execute("DROP TRIGGER IF EXISTS trg_remover_cliente_especial")
cursor.execute("""
    CREATE TRIGGER trg_remover_cliente_especial
    AFTER UPDATE ON clienteespecial
    FOR EACH ROW
    BEGIN
      IF NEW.cashback = 0 THEN
        DELETE FROM clienteespecial WHERE id = NEW.id;
      END IF;
    END
""")

conn.commit()

print("Banco de dados aquarismo configurado com sucesso.")

cursor.close()
conn.close()