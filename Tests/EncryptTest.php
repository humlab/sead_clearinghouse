<?php
/**
 * Generated by PHPUnit_SkeletonGenerator 1.2.1 on 2014-03-12 at 09:10:38.
 */

use PHPUnit\Framework\TestCase;

class EncryptTest extends TestCase
{

    /**
     * Sets up the fixture, for example, opens a network connection.
     * This method is called before a test is executed.
     */
    protected function setUp()
    {
    }

    /**
     * Tears down the fixture, for example, closes a network connection.
     * This method is called after a test is executed.
     */
    protected function tearDown()
    {
    }
    /**
     * @covers Repository\ActivityRepository::findByEntityId
     * @todo   Implement testFindByEntityId().
     */
    public function testDecodeOfEncodeIsTheSame()
    {

        $secret_string = "This is the secret string";
        $secret_key = "This is the secret key!";

        $converter = new \Services\EncryptService();
        $encoded = $converter->encode($secret_key, $secret_string );
        $decoded = $converter->decode($secret_key, $encoded);

        $this->assertEquals($secret_string, $decoded);

    }

}
