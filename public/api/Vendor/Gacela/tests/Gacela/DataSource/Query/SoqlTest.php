<?php
namespace Gacela\DataSource\Query;

/**
 * Generated by PHPUnit_SkeletonGenerator on 2012-10-18 at 09:05:30.
 */
class SoqlTest extends \Test\GUnit\TestCase
{
	/**
	 * @var Soql
	 */
	protected $object;

	protected function setUp()
	{
		parent::setUp();

		$this->object = new Soql;
	}

	public function testSelect()
	{
		list($query, $args) = $this->object
			->from('Account')
			->where('Id = :test', array(':test' => '1234'))
			->assemble();

		$this->assertSame("SELECT *\nFROM Account\nWHERE (Id = '1234')\n", $query);
	}

	public function providerEqualsAsConstant()
	{
		return array
		(
			array("Id = '000000123456789GBF'"),
			array("Id='000000123456789GBF'"),
			array('Id="000000123456789GBF"'),
			array('Id = "000000123456789GBF"'),
			array('Id = 000000123456789GBF'),
			array('Id=000000123456789GBF')
		);
	}

	public function testDeleteWithEqualsAsBoundParam()
	{
		$this->object->delete('Account')->where('Id = :test', array(':test' => '000000123456789GBF'));

		list($query, $args) = $this->object->assemble();

		$this->assertSame(array('000000123456789GBF'), $args['Ids']);
	}

	/**
	 * @param $where
	 * @dataProvider providerEqualsAsConstant
	 */
	public function testDeleteWithEqualsAsConstant($where)
	{
		$this->object->delete('Account')->where($where);

		list($query, $args) = $this->object->assemble();

		$this->assertSame(array('000000123456789GBF'), $args['Ids']);
	}

	public function testDeleteWithIn()
	{
		$ids = array('001g0000004l7eE', '001g0000004l7af', '001g0000004l7a1');

		list($query, $args) = $this->object
			->delete('Account')
			->in('Id', $ids)
			->assemble();

		$this->assertSame($ids, $args['Ids']);
	}
}
