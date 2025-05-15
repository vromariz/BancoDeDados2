from connection import get_connection
import user_controller
import stats_controller

def login(cursor):
    print("=== LOGIN DO SISTEMA ===")
    user_id = input("Digite o ID do funcionário: ")

    cursor.execute("SELECT * FROM funcionario WHERE id = %s", (user_id,))
    user = cursor.fetchone()

    if not user:
        print("⚠️ Funcionário não encontrado.")
        return None
    else:
        print(f"✅ Bem-vindo(a), {user['nome']} | Cargo: {user['cargo'].upper()}")
        return user
    
def main():
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)

    usuario = login(cursor)
    if not usuario:
        cursor.close()
        conn.close()
        return
    
    print(f"Bem-vindo(a)!")
    while True:
        print("\n ===========--- MENU ---===========")
        print("1. Cadastrar produto")
        print("2. Registrar venda")
        print("3. Visualizar estatísticas")
        print("4. Listar produtos")
        print("5. Listar clientes")
        print("0. Sair")
        print("=====================================")
        opcao = input("Escolha: ")

        if opcao == "1":
            user_controller.cadastrar_produto(usuario)     
        elif opcao == "2":
            registrar_venda(cursor, conn, id_vendedor=usuario['id'])
        elif opcao == "3":
            mostrar_estatisticas(cursor)
        elif opcao == "4":
            user_controller.listar_produtos()
        elif opcao == "5":
            user_controller.listar_clientes()
        elif opcao == "0":
            print("Saindo...")
            break
        else:
            print("Opção inválida.")
    
    cursor.close()
    conn.close()

def registrar_venda(cursor, conn, id_vendedor):
    id_cliente = input("ID do cliente: ")
    id_produto = input("ID do produto: ")
    data = input("Data (YYYY-MM-DD): ")
    
    cursor.execute("""
        INSERT INTO venda (id_vendedor, id_cliente, data)
        VALUES (%s, %s, %s)
    """, (id_vendedor, id_cliente, data))

    conn.commit()
    print("✅ Venda registrada.")


def mostrar_estatisticas(cursor):
    print("Produtos mais vendidos:")
    cursor.execute("""
        SELECT p.descricao, COUNT(*) AS total_vendas 
        FROM venda v 
        JOIN produto p ON v.id = p.id 
        GROUP BY p.descricao 
        ORDER BY total_vendas DESC 
        LIMIT 1
    """)
    for row in cursor.fetchall():
        print(f"{row['descricao']}: {row['total_vendas']} vendas")

if __name__ == "__main__":
    main()