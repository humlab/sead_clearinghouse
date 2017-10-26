<?php
namespace Gacela\Field;

/**
 * Generated by PHPUnit_SkeletonGenerator on 2012-09-30 at 06:31:11.
 */
class SetTest extends \PHPUnit_Framework_TestCase
{

    protected $meta;

	/**
	 * @var Set
	 */
	protected $object;

    /**
     * Sets up the fixture, for example, opens a network connection.
     * This method is called before a test is executed.
     */
    protected function setUp()
    {
		$this->object = new Set;

        $this->meta = (object) array(
			'type' => 'set',
			'values' => array(1, 'one', 'two', 2),
			'null' => false
		);
    }

	public function providerValueCode()
	{
		return array(
			array(3),
			array('three'),
			array(array(1, 3)),
			array(array('two', 4))
		);
	}

	public function providerPass()
	{
		return array(
			array('one', 'one'),
			array(2, '2'),
			array(array(1, 2), "1,2"),
			array(array('one', 2), "one,2")
		);
	}

    /**
     * @covers Gacela\Field\Set::validate
	 * @dataProvider providerValueCode
     */
    public function testValidateValueCode($value)
    {
        $this->assertEquals(Set::VALUE_CODE, $this->object->validate($this->meta, $value));
    }

	/**
	 * @covers Gacela\Field\Set::validate
	 */
	public function testValidateNullCode()
	{
		$this->assertEquals(Set::NULL_CODE, $this->object->validate($this->meta, null));
	}

	/**
	 * @covers Gacela\Field\Set::validate
	 * @dataProvider providerPass
	 */
	public function testValidatePass($value)
	{
		$this->assertTrue($this->object->validate($this->meta, $value));
	}

	/**
	 * @covers Gacela\Field\Set::validate
	 */
	public function testValidatePassNull()
	{
		$this->meta->null = true;

		$this->assertTrue($this->object->validate($this->meta, null));
	}

    /**
     * @covers Gacela\Field\Set::transform
	 * @dataProvider providerPass
     */
    public function testTransformIn($in, $out)
    {
		$this->assertSame($out, $this->object->transform($this->meta, $in, true));
    }

	/**
	 * @covers Gacela\Field\Set::transform
	 * @dataProvider providerPass
	 */
	public function testTransformOut($value)
	{
		$this->assertSame($value, $this->object->transform($this->meta, $value, false));
	}
}
