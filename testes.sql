/*---------------------------------------------------------------------------------------------------------------------
                                    EXCLUSÕES
---------------------------------------------------------------------------------------------------------------------*/

DROP TABLE vendas;
DROP TABLE produtos;
DROP TABLE estoque;

/*---------------------------------------------------------------------------------------------------------------------
                                    FUNÇÃO calcular_preco
---------------------------------------------------------------------------------------------------------------------*/

SELECT * FROM calcular_preco(100, 100, 50);

/*---------------------------------------------------------------------------------------------------------------------
                                    FUNÇÃO calcular_valor_da_venda
---------------------------------------------------------------------------------------------------------------------*/

SELECT * FROM calcular_valor_da_venda(1.5, 2);

/*---------------------------------------------------------------------------------------------------------------------
                                    FUNÇÃO registrar_produto_no_estoque
---------------------------------------------------------------------------------------------------------------------*/

SELECT * FROM registrar_produto_no_estoque('abacate', 300, 455, 22, '2024-03-21');
SELECT * FROM registrar_produto_no_estoque('banana', 250, 265, 25, '2024-03-21');
SELECT * FROM registrar_produto_no_estoque('morango', 650, 832, 45, '2024-03-21');
SELECT * FROM registrar_produto_no_estoque('laranja', 250, 440, 15, '2024-03-21');
SELECT * FROM registrar_produto_no_estoque('tomate', 500, 732, 25, '2024-03-21');

/*---------------------------------------------------------------------------------------------------------------------
                                    FUNÇÃO registrar_venda
---------------------------------------------------------------------------------------------------------------------*/

SELECT * FROM registrar_venda('morango', 20);
SELECT * FROM registrar_venda('morango', 12);
SELECT * FROM registrar_venda('morango', 8);
SELECT * FROM registrar_venda('morango', 8, 5);

SELECT * FROM registrar_venda('banana', 6);
SELECT * FROM registrar_venda('banana', 18, 7);

SELECT * FROM registrar_venda('abacate', 8);
SELECT * FROM registrar_venda('abacate', 6);
SELECT * FROM registrar_venda('abacate', 4);
SELECT * FROM registrar_venda('abacate', 3);

/*---------------------------------------------------------------------------------------------------------------------
                                    FUNÇÃO selecionar_produto_em_estoque
---------------------------------------------------------------------------------------------------------------------*/

SELECT * FROM selecionar_produto_em_estoque();
SELECT * FROM selecionar_produto_em_estoque('abacate');

/*---------------------------------------------------------------------------------------------------------------------
                                    FUNÇÃO selecionar_vendas
---------------------------------------------------------------------------------------------------------------------*/

SELECT * FROM selecionar_vendas('abacate');

/*---------------------------------------------------------------------------------------------------------------------
                                    FUNÇÃO selecionar_produto_para_venda
---------------------------------------------------------------------------------------------------------------------*/

SELECT * FROM selecionar_produto_para_venda();
SELECT * FROM selecionar_produto_para_venda('abacate');

/*---------------------------------------------------------------------------------------------------------------------
                                    FUNÇÃO atualizar_dados_estoque_e_produto
---------------------------------------------------------------------------------------------------------------------*/

SELECT * FROM selecionar_produto_em_estoque('abacate');
SELECT * FROM atualizar_dados_estoque_e_produto('abacate', 100, 100, 5 );

/*---------------------------------------------------------------------------------------------------------------------
                                    FUNÇÃO deletar_produto
---------------------------------------------------------------------------------------------------------------------*/

SELECT * FROM selecionar_produto_em_estoque();
SELECT * FROM selecionar_produto_para_venda();
SELECT * FROM selecionar_vendas();
SELECT * FROM deletar_produto('morango');

