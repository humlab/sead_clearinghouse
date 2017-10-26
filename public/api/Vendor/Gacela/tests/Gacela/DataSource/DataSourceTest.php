<?php
namespace Gacela\DataSource;

/**
 * Generated by PHPUnit_SkeletonGenerator on 2012-10-17 at 00:30:51.
 */
class DataSourceTest extends \Test\GUnit\TestCase
{
    /**
     * @var DataSource
     */
    protected $object;

    /**
     * Sets up the fixture, for example, opens a network connection.
     * This method is called before a test is executed.
     */
    protected function setUp()
    {
		$config = array(
			'name' => 'test',
			'type' => 'mysql'
		);

		$adapter = $this->getMock('\Gacela\DataSource\Adapter\Mysql', array(), array(\Gacela::instance(), (object) $config));

		$adapter->expects($this->any())
			->method('load')
			->will(
				$this->returnValue(
					array(
						'columns' => array(
							'id' => (object) array(
								'type' => 'int',
								'min' => '0',
								'max' => '65356',
								'length' => '10',
								'sequenced' => true,
								'null' => false,
								'unsigned' => true
							)
						),
						'relations' => array(),
						'primary' => array('id'),
						'name' => 'test'
					)
				)
			);

        $this->object = $this->getMockForAbstractClass('\Gacela\DataSource\DataSource', array(\Gacela::instance(), $adapter, $config));
    }

	protected function tearDown()
	{
		\Gacela::reset();
	}

    /**
     * @covers Gacela\DataSource\DataSource::beginTransaction
     */
    public function testBeginTransaction()
    {
		$this->assertTrue($this->object->beginTransaction());
    }

    /**
     * @covers Gacela\DataSource\DataSource::createConfig
     * @todo   Implement testCreateConfig().
     */
    public function testCreateConfig()
    {
        // Remove the following lines when you implement this test.
        $this->markTestIncomplete(
          'This test has not been implemented yet.'
        );
    }

    /**
     * @covers Gacela\DataSource\DataSource::commitTransaction
     */
    public function testCommitTransaction()
    {
        $this->assertTrue($this->object->commitTransaction());
    }

    /**
     * @covers Gacela\DataSource\DataSource::lastQuery
     * @todo   Implement testLastQuery().
     */
    public function testLastQuery()
    {
        $this->assertSame(array(), $this->object->lastQuery());
    }

    /**
     * @covers Gacela\DataSource\DataSource::loadResource
     */
    public function testLoadResource()
    {
		$this->assertInstanceOf('\Gacela\DataSource\Resource', $this->object->loadResource('test'));
    }

	public function testLoadResourceCached()
	{
		$this->assertFalse(\Gacela::instance()->cacheMetaData('test_resource_test'));

		$test = $this->object->loadResource('test');

		$this->assertSame($test, \Gacela::instance()->cacheMetaData('test_resource_test'));
	}

	public function testLoadResourceWithMemcache()
	{
		$memcache = new \Memcache;

		$memcache->addServer('127.0.0.1', 11211);

		$memcache->flush();

		\Gacela::instance()->enableCache($memcache);

		$this->assertFalse($memcache->get('test_resource_test'));

		$test = $this->object->loadResource('test');

		$this->assertEquals($test, $memcache->get('test_resource_test'));
	}

    /**
     * @covers Gacela\DataSource\DataSource::rollbackTransaction
     */
    public function testRollbackTransaction()
    {
		$this->assertTrue($this->object->rollbackTransaction());
    }
}
