#!/usr/bin/env node

/**
 * 测试 Bailian Coding API 支持的模型
 * 特别测试 qwen3.6-plus 是否可用
 */

const https = require('https');
const fs = require('fs');

// 配置
const API_KEY = fs.readFileSync('/root/.opencode/api_key_bailian_coding.txt', 'utf-8').trim();
const BASE_URL = 'https://coding.dashscope.aliyuncs.com/v1';

console.log('========================================');
console.log('Bailian Coding API 模型测试');
console.log('========================================\n');
console.log('API Key:', API_KEY.substring(0, 10) + '...');
console.log('Base URL:', BASE_URL);
console.log('\n');

/**
 * 发送 HTTP 请求
 */
function makeRequest(path, method = 'GET', body = null) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'coding.dashscope.aliyuncs.com',
      port: 443,
      path: path,
      method: method,
      headers: {
        'Authorization': `Bearer ${API_KEY}`,
        'Content-Type': 'application/json'
      }
    };

    const req = https.request(options, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          resolve({ status: res.statusCode, data: parsed, rawData: data });
        } catch (e) {
          resolve({ status: res.statusCode, data: data, rawData: data });
        }
      });
    });

    req.on('error', (e) => {
      reject(e);
    });

    if (body) {
      req.write(JSON.stringify(body));
    }

    req.end();
  });
}

/**
 * 测试特定模型并显示完整错误信息
 */
async function testModel(modelName) {
  console.log(`测试模型 "${modelName}"...`);
  
  const testMessage = {
    model: modelName,
    messages: [
      { role: 'user', content: '你好，请回复"测试成功"' }
    ],
    max_tokens: 50,
    temperature: 0.1
  };

  try {
    const response = await makeRequest('/v1/chat/completions', 'POST', testMessage);
    
    console.log('状态码:', response.status);
    
    if (response.status === 200) {
      console.log('✅ 模型可用！');
      
      if (response.data.choices && response.data.choices[0]) {
        const content = response.data.choices[0].message?.content || response.data.choices[0].text;
        console.log('模型回复:', content);
      }
      
      console.log('\n完整响应:');
      console.log(JSON.stringify(response.data, null, 2));
    } else {
      console.log('❌ 请求失败');
      console.log('\n完整错误响应:');
      console.log(JSON.stringify(response.data, null, 2));
      
      if (response.data.error) {
        console.log('\n错误详情:');
        console.log('  类型:', response.data.error.type || 'N/A');
        console.log('  消息:', response.data.error.message || 'N/A');
        console.log('  代码:', response.data.error.code || 'N/A');
      }
    }
  } catch (error) {
    console.log('❌ 请求失败:', error.message);
  }
  
  console.log('\n' + '='.repeat(80) + '\n');
}

/**
 * 测试 qwen3.6-plus 的各种可能命名
 */
async function testQwen36PlusVariants() {
  console.log('测试 qwen3.6-plus 的各种可能命名...\n');
  
  // 可能的模型名称变体
  const candidateNames = [
    'qwen3.6-plus',
    'qwen3.6-plus-latest',
    'qwen3-6-plus',
    'qwen-3.6-plus',
    'qwen3.6',
    'qwen3.6-coder',
    'qwen3.6-coder-plus',
    'qwen3-6-coder-plus'
  ];
  
  for (const name of candidateNames) {
    await testModel(name);
  }
}

/**
 * 测试已知支持的模型
 */
async function testKnownModels() {
  console.log('测试已知支持的模型...\n');
  
  const knownModels = ['glm-5', 'qwen3.5-plus', 'kimi-k2.5', 'MiniMax-M2.5'];
  
  for (const model of knownModels) {
    await testModel(model);
  }
}

// 主函数
async function main() {
  try {
    // 先测试已知模型
    await testKnownModels();
    
    // 再测试 qwen3.6-plus 的各种变体
    await testQwen36PlusVariants();
    
    console.log('========================================');
    console.log('测试完成');
    console.log('========================================');
  } catch (error) {
    console.error('测试过程中发生错误:', error);
  }
}

main();